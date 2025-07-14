import Foundation
import GRPCLib
import NIO
import NIOPortForwarding
import Semaphore
import Virtualization

public protocol VirtualMachineDelegate {
	func didChangedState(_ vm: VirtualMachine)
}

public final class VirtualMachine: NSObject, VZVirtualMachineDelegate, ObservableObject, VirtioSocketDeviceDelegate {
	static func == (lhs: VirtualMachine, rhs: VirtualMachine) -> Bool {
		lhs.vmLocation.rootURL == rhs.vmLocation.rootURL
	}

	public typealias StartCompletionHandler = (Result<Void, any Error>) -> Void
	public typealias StopCompletionHandler = ((any Error)?) -> Void

	public var virtualMachine: VZVirtualMachine
	public let config: CakeConfig
	public let vmLocation: VMLocation
	public var delegate: VirtualMachineDelegate? = nil

	private let communicationDevices: CommunicationDevices?
	private let configuration: VZVirtualMachineConfiguration
	private let networks: [NetworkAttachement]
	private let sigcaught: [Int32: DispatchSourceSignal]
	private var semaphore = AsyncSemaphore(value: 0)
	private var mountService: MountServiceServerProtocol? = nil
	private var requestStopFromUIPending = false
	private var runningIP: String = ""
	private let runMode: Utils.RunMode

	public var suspendable: Bool {
		return self.config.suspendable
	}

	public var status: VMLocation.Status {
		if self.runMode != .app {
			return self.vmLocation.status
		}

		switch self.virtualMachine.state {
		case .running, .starting, .resuming:
			return .running
		case .paused, .pausing:
			return .suspended
		default:
			return .stopped
		}
	}

	private static func createCloudInitDrive(cdromURL: URL) throws -> VZStorageDeviceConfiguration {
		let attachment: VZDiskImageStorageDeviceAttachment = try VZDiskImageStorageDeviceAttachment(
			url: cdromURL,
			readOnly: true,
			cachingMode: .cached,
			synchronizationMode: VZDiskImageSynchronizationMode.none)

		let cdrom = VZVirtioBlockDeviceConfiguration(attachment: attachment)

		cdrom.blockDeviceIdentifier = "CIDATA"

		return cdrom
	}

	public init(vmLocation: VMLocation, config: CakeConfig, runMode: Utils.RunMode) throws {

		if config.arch != Architecture.current() {
			throw ServiceError("Unsupported architecture")
		}

		let suspendable = config.suspendable
		let networks: [any NetworkAttachement] = try config.collectNetworks(runMode: runMode)
		let additionalDiskAttachments = try config.additionalDiskAttachments()
		let directorySharingAttachments = try config.directorySharingAttachments()
		let socketDeviceAttachments = try config.socketDeviceAttachments(agentURL: vmLocation.agentURL)
		let consoleURL = try config.consoleAttachment()

		let configuration = VZVirtualMachineConfiguration()
		let plateform = try config.platform(nvramURL: vmLocation.nvramURL, needsNestedVirtualization: config.nested)
		let soundDeviceConfiguration = VZVirtioSoundDeviceConfiguration()
		let memoryBallons = VZVirtioTraditionalMemoryBalloonDeviceConfiguration()

		var sigcaught: [Int32: DispatchSourceSignal] = [:]
		var devices: [VZStorageDeviceConfiguration] = [
			VZVirtioBlockDeviceConfiguration(
				attachment: try VZDiskImageStorageDeviceAttachment(
					url: vmLocation.diskURL,
					readOnly: false,
					cachingMode: config.os == .linux ? .cached : .automatic,
					synchronizationMode: .full
				))
		]

		let networkDevices = try networks.map {
			let vio = VZVirtioNetworkDeviceConfiguration()

			(vio.macAddress, vio.attachment) = try $0.attachment(vmLocation: vmLocation, runMode: runMode)

			return vio
		}

		devices.append(contentsOf: additionalDiskAttachments)

		soundDeviceConfiguration.streams = [VZVirtioSoundDeviceOutputStreamConfiguration()]

		configuration.bootLoader = try plateform.bootLoader()
		configuration.cpuCount = config.cpuCount
		configuration.memorySize = config.memorySize
		configuration.platform = try plateform.platform()
		configuration.graphicsDevices = [plateform.graphicsDevice(vmConfig: config)]
		configuration.audioDevices = [soundDeviceConfiguration]
		configuration.keyboards = plateform.keyboards(suspendable)
		configuration.pointingDevices = plateform.pointingDevices(suspendable)
		configuration.networkDevices = networkDevices
		configuration.storageDevices = devices
		configuration.directorySharingDevices = directorySharingAttachments
		configuration.serialPorts = []
		configuration.memoryBalloonDevices = [memoryBallons]

		let spiceAgentConsoleDevice = VZVirtioConsoleDeviceConfiguration()
		let spiceAgentPort = VZVirtioConsolePortConfiguration()
		let spiceAgentPortAttachment = VZSpiceAgentPortAttachment()

		spiceAgentPortAttachment.sharesClipboard = true

		spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
		spiceAgentPort.attachment = spiceAgentPortAttachment
		spiceAgentConsoleDevice.ports[0] = spiceAgentPort
		configuration.consoleDevices.append(spiceAgentConsoleDevice)

		if config.os == .linux {
			let cdromURL = URL(fileURLWithPath: cloudInitIso, relativeTo: vmLocation.diskURL).absoluteURL

			if FileManager.default.fileExists(atPath: cdromURL.path) {
				devices.append(try Self.createCloudInitDrive(cdromURL: cdromURL))
			}
		}

		let communicationDevices = try CommunicationDevices.setup(group: Utilities.group, configuration: configuration, consoleURL: consoleURL, sockets: socketDeviceAttachments)

		try configuration.validate()

		let virtualMachine = VZVirtualMachine(configuration: configuration)

		if runMode != .app {
			sigcaught = [SIGINT, SIGUSR1, SIGUSR2].reduce(into: [Int32: DispatchSourceSignal]()) { partialResult, sig in
				partialResult[sig] = DispatchSource.makeSignalSource(signal: sig)
			}
		}

		self.runMode = runMode
		self.config = config
		self.vmLocation = vmLocation
		self.configuration = configuration
		self.communicationDevices = communicationDevices
		self.virtualMachine = virtualMachine
		self.networks = networks
		self.sigcaught = sigcaught

		super.init()

		if vmLocation.template == false && (config.forwardedPorts.isEmpty == false || config.dynamicPortForwarding) {
			communicationDevices.delegate = self
		}

		virtualMachine.delegate = self
	}

	public func getVM() -> VZVirtualMachine {
		return self.virtualMachine
	}

	private func start(completionHandler: StartCompletionHandler? = nil) async throws {
		var resumeVM: Bool = false

		self.mountService = createMountServiceServer(group: Utilities.group.next(), runMode: runMode, vm: self, certLocation: try CertificatesLocation.createAgentCertificats(runMode: runMode))

		#if arch(arm64)
			if #available(macOS 14, *) {
				if FileManager.default.fileExists(atPath: vmLocation.stateURL.path) {
					Logger(self).info("Restore VM \(self.vmLocation.name) snapshot...")

					try await virtualMachine.restoreMachineStateFrom(url: vmLocation.stateURL)
					try FileManager.default.removeItem(at: vmLocation.stateURL)

					resumeVM = true
				}
			}

			if resumeVM {
				Logger(self).info("Resume VM \(self.vmLocation.name)...")
				self.resumeVM(completionHandler: completionHandler)
			} else {
				Logger(self).info("Start VM \(self.vmLocation.name)...")
				self.startVM(completionHandler: completionHandler)
			}
		#else
			Logger(self).info("Start VM \(self.vmLocation.name)...")
			self.startVM(completionHandler: completionHandler)
		#endif

		defer {
			stopMountService()
			stopNetworkDevices()
		}

		do {
			mountService!.serve()
			try await self.semaphore.waitUnlessCancelled()
		} catch is CancellationError {
		}

		if Task.isCancelled {
			if virtualMachine.state == VZVirtualMachine.State.running {
				Logger(self).info("Stopping VM \(self.vmLocation.name)...")
				self.stopVM()
			}
		}

		Logger(self).info("VM \(self.vmLocation.name) exited")
	}

	private func startCompletionHandler(result: Result<Void, any Error>, completionHandler: VirtualMachine.StartCompletionHandler? = nil) {
		self.requestStopFromUIPending = false

		switch result {
		case .success:
			Logger(self).info("VM \(self.vmLocation.name) started")
			self.startCommunicationDevices()
			break
		case .failure(let error):
			Logger(self).error("VM \(self.vmLocation.name) failed to start: \(error)")
		}

		if let completionHandler: VirtualMachine.StartCompletionHandler = completionHandler {
			completionHandler(result)
		}
	}

	public func startFromUI() {
		self.virtualMachine.start { result in
			self.startCompletionHandler(result: result) { result in
				if case .success = result {
					guard (try? self.startedVM(on: Utilities.group.next(), runMode: self.runMode)) != nil else {
						Logger(self).error("VM \(self.vmLocation.name) failed to get primary IP")
						return
					}
				}
			}
		}
	}

	public func startVM(completionHandler: StartCompletionHandler? = nil) {
		DispatchQueue.main.sync {
			if self.virtualMachine.canStart {
				self.virtualMachine.start { result in
					self.startCompletionHandler(result: result, completionHandler: completionHandler)
				}
			}
		}
	}

	private func _pauseVM(completionHandler: StartCompletionHandler? = nil) {
		if self.virtualMachine.canPause {
			if #available(macOS 14, *) {
				do {
					try self.configuration.validateSaveRestoreSupport()

					self.virtualMachine.pause { result in
						if case let .failure(err) = result {
							Logger(self).error("Failed to pause VM \(self.vmLocation.name) \(err)")
							if let completionHandler = completionHandler {
								completionHandler(result)
							}
						} else {
							Logger(self).info("VM \(self.vmLocation.name) paused")

							self.stopServices()

							self.virtualMachine.saveMachineStateTo(url: self.vmLocation.stateURL) { result in
								if let error = result {
									if let completionHandler = completionHandler {
										completionHandler(.failure(error))
									}
								} else {
									Logger(self).info("Snap created successfully...")

									if let completionHandler = completionHandler {
										completionHandler(.success(()))
									}
								}
							}
						}

						self.didChangedState()
					}
				} catch {
					Logger(self).warn("Snapshot is only supported on macOS 14 or newer")

					if let completionHandler = completionHandler {
						completionHandler(.failure(error))
					}
				}
			} else {
				self.virtualMachine.pause { result in
					if case let .failure(err) = result {
						Logger(self).error("Failed to pause VM \(self.vmLocation.name) \(err)")
					} else {
						Logger(self).info("VM \(self.vmLocation.name) paused")

						self.stopServices()
					}

					if let completionHandler = completionHandler {
						completionHandler(result)
					}

					self.didChangedState()
				}
			}
		}
	}

	public func pauseVM(completionHandler: StartCompletionHandler? = nil) {
		DispatchQueue.main.sync {
			self._pauseVM(completionHandler: completionHandler)
		}
	}

	public func resumeVM(completionHandler: StartCompletionHandler? = nil) {
		DispatchQueue.main.sync {
			if self.virtualMachine.canResume {
				Logger(self).info("VM \(self.vmLocation.name) can resume")

				self.virtualMachine.resume { result in
					self.startCompletionHandler(result: result, completionHandler: completionHandler)
				}
			}
		}
	}

	private func _stopVM(completionHandler: StopCompletionHandler? = nil) {
		self.virtualMachine.stop { result in
			Logger(self).info("VM \(self.vmLocation.name) stopped")

			self.stopServices()

			if let completionHandler = completionHandler {
				completionHandler(result)
			}

			self.didChangedState()
		}
	}

	public func stopVM(completionHandler: StopCompletionHandler? = nil) {
		DispatchQueue.main.sync {
			self._stopVM(completionHandler: completionHandler)
		}
	}

	public func stopFromUI() {
		self._stopVM()
	}

	private func _requestStopVM() throws {
		self.requestStopFromUIPending = true

		if self.virtualMachine.canRequestStop {
			Logger(self).info("Requesting stop VM \(self.vmLocation.name)...")
			try self.virtualMachine.requestStop()
		} else if self.virtualMachine.canStop {
			self.virtualMachine.stop { result in
				Logger(self).info("VM \(self.vmLocation.name) stopped")

				self.stopServices()
				self.didChangedState()

				if self.runMode == .app {
					try? self.vmLocation.deletePID()
				}
			}
		} else if self.virtualMachine.state == VZVirtualMachine.State.starting {
			Logger(self).error("VM \(self.vmLocation.name) can't be stopped")

			if self.runMode != .app {
				throw ExitCode(EXIT_FAILURE)
			}
		}
	}

	public func requestStopVM() throws {
		try DispatchQueue.main.sync {
			try self._requestStopVM()
		}
	}

	public func requestStopFromUI() throws {
		try self._requestStopVM()
	}

	public func suspendFromUI() {
		self._pauseVM()
	}

	private func startCommunicationDevices() {
		if let communicationDevices = self.communicationDevices {
			communicationDevices.connect(virtualMachine: self.virtualMachine)
			Logger(self).info("Communication devices \(self.vmLocation.name) connected")
		}
	}

	private func signalStop() {
		Logger(self).info("Signal VM \(self.vmLocation.name) stopped...")
		stopServices()

		if self.requestStopFromUIPending == false {
			self.semaphore.signal()
		}

		self.requestStopFromUIPending = true

		if self.runMode == .app {
			try? self.vmLocation.deletePID()
		}
	}

	private func stopForwaringPorts() {
		try? PortForwardingServer.closeForwardedPort()
	}

	private func stopMountService() {
		if let mountService = self.mountService {
			Logger(self).info("Stopping mount service for VM \(self.vmLocation.name)...")
			mountService.stop()
		}
	}

	private func stopCommunicationDevices() {
		if let communicationDevices = self.communicationDevices {
			Logger(self).info("Close communication devices for VM \(self.vmLocation.name)")
			communicationDevices.close()
		}
	}

	private func stopNetworkDevices() {
		self.networks.forEach { $0.stop(runMode: runMode) }
	}

	private func stopServices() {
		stopCommunicationDevices()
		stopForwaringPorts()
	}

	private func catchUserSignals(_ task: Task<Int32, Never>) {
		sigcaught[SIGINT]!.setEventHandler {
			task.cancel()
		}

		sigcaught[SIGUSR1]!.setEventHandler {
			self.pauseVM { result in
				task.cancel()
			}
		}

		sigcaught[SIGUSR2]!.setEventHandler {
			if self.requestStopFromUIPending == false {
				try? self.requestStopVM()
			}
		}

		sigcaught.forEach { (key: Int32, value: any DispatchSourceSignal) in
			signal(key, SIG_IGN)
			value.activate()
		}
	}

	private func startedVM(on: EventLoop, promise: EventLoopPromise<String?>? = nil, runMode: Utils.RunMode) throws -> EventLoopFuture<String?> {

		if self.runMode == .app {
			try self.vmLocation.writePID()
		}

		let config = self.config
		let response = try self.vmLocation.waitIP(on: on, config: config, wait: 120, runMode: runMode)

		response.whenSuccess { runningIP in
			if let promise = promise {
				promise.succeed(runningIP)
			}

			guard let runningIP = runningIP else {
				Logger(self).error("VM \(self.vmLocation.name) failed to get primary IP")
				return
			}

			Logger(self).info("VM \(self.vmLocation.name) started with primary IP: \(runningIP)")

			self.runningIP = runningIP

			if config.firstLaunch && config.agent == false {
				do {
					config.agent = try self.vmLocation.installAgent(config: config, runningIP: runningIP, runMode: runMode)
				} catch {
					Logger(self).error("VM \(self.vmLocation.name) failed to install agent: \(error)")
				}
			}

			if config.agent {
				if let infos = try? self.vmLocation.vmInfos(runMode: runMode) {
					config.osName = infos.osname
					config.osRelease = infos.release
				}
			}

			config.runningIP = runningIP
			config.firstLaunch = false

			try? config.save()

			self.didChangedState()
		}

		response.whenFailure { error in
			if let promise = promise {
				promise.fail(error)
			}

			self.didChangedState()

			Logger(self).error("VM \(self.vmLocation.name) failed to get primary IP: \(error)")
		}

		return response
	}

	public func runInBackground(on: EventLoop, internalCall: Bool, promise: EventLoopPromise<String?>? = nil, completionHandler: StartCompletionHandler? = nil) throws -> EventLoopFuture<String?> {
		let task = Task {
			var status: Int32 = 0

			do {
				try await self.start(completionHandler: completionHandler)
			} catch {
				status = 1
			}

			self.vmLocation.removePID()

			guard internalCall else {
				Foundation.exit(status)
			}

			return status
		}

		if self.vmLocation.template == false && self.runMode != .app {
			self.catchUserSignals(task)
		}

		return try self.startedVM(on: on, promise: promise, runMode: runMode)
	}

	public func guestDidStop(_ virtualMachine: VZVirtualMachine) {
		Logger(self).info("VM \(self.vmLocation.name) stopped")

		self.signalStop()
		self.didChangedState()
	}

	public func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
		Logger(self).error(error)

		self.signalStop()
		self.didChangedState()
	}

	public func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: any Error) {
		Logger(self).error(error)

		self.signalStop()
		self.didChangedState()
	}

	func closedByRemote(socket: SocketDevice) {
	}

	func connectionInitiatedByGuest(socket: SocketDevice) {
	}

	func connectionInitiatedByHost(socket: SocketDevice) {
		if socket.bind == self.vmLocation.agentURL.path {
			Logger(self).info("Configure forwarding ports for VM \(self.vmLocation.name)")

			do {
				try PortForwardingServer.createPortForwardingServer(
					group: Utilities.group.next(), remoteAddress: self.runningIP, forwardedPorts: self.config.forwardedPorts, dynamicPortForwarding: config.dynamicPortForwarding, listeningAddress: self.vmLocation.agentURL, runMode: runMode)
			} catch {
				Logger(self).error(error)
			}
		}
	}

	func didChangedState() {
		DispatchQueue.main.async {
			if let delegate = self.delegate {
				delegate.didChangedState(self)
			}
		}
	}
}
