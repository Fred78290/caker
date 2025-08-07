import Foundation
import GRPCLib
import NIO
import NIOPortForwarding
import Semaphore
import Virtualization
import Socket
import Shout

public protocol VirtualMachineDelegate {
	func didChangedState(_ vm: VirtualMachine)
}

extension SSHError.Kind {
	var description: String {
		switch self {
		case .authenticationFailed:
			return "Authentication failed"
		case .channelFailure:
			return "Channel failure"
		case .channelClosed:
			return "Channel closed"
		case .channelRequestDenied:
			return "Channel request denied"
		case .genericError:
			return "Unknow error"
		case .bannerRecv:
			return "Banner recv"
		case .bannerSend:
			return "Banner send"
		case .invalidMac:
			return "Invalic mac address"
		case .kexFailure:
			return "kext failure"
		case .alloc:
			return "allocation failure"
		case .socketSend:
			return "error socket"
		case .keyExchangeFailure:
			return "key exchange failure"
		case .errorTimeout:
			return "connection timeout"
		case .hostkeyInit, .hostkeySign, .decrypt:
			return "SSH key problem"
		case .socketDisconnect:
			return "socket disconnect"
		case .proto:
			return "wrong protocol"
		case .passwordExpired:
			return "password expired"
		case .file:
			return "file error"
		case .methodNone:
			return "wrong method"
		case .publicKeyUnverified:
			return "public key can't be verified"
		case .channelOutOfOrder, .channelUnknown, .channelWindowExceeded, .channelPacketExceeded, .channelEofSent, .channelWindowFull:
			return "channel error"
		case .scpProtocol, .sftpProtocol:
			return "exchange protocol error"
		case .zlib:
			return "zlib error"
		case .socketTimeout:
			return "some socket timeout"
		case .requestDenied:
			return "request denied"
		case .methodNotSupported:
			return "method not supported"
		case .inval:
			return "invalid argument"
		case .invalidPollType:
			return "invalid poll type"
		case .publicKeyProtocol:
			return "wrong public key protocol"
		case .eagain:
			return "some socket error"
		case .bufferTooSmall:
			return "buffer too small"
		case .badUse:
			return "bad use"
		case .compress:
			return "compress error"
		case .outOfBoundary:
			return "out of boundary"
		case .agentProtocol:
			return "agent protocol error"
		case .socketRecv:
			return "socket recv error"
		case .encrypt:
			return "encrypt error"
		case .badSocket:
			return "bad socket"
		case .knownHosts:
			return "wrong known hosts"
		case .keyfileAuthFailed:
			return "key authentication failed"
		}
	}
}

class VirtualMachineEnvironment: VirtioSocketDeviceDelegate {
	let location: VMLocation
	let config: CakeConfig
	let communicationDevices: CommunicationDevices?
	let configuration: VZVirtualMachineConfiguration
	let networks: [NetworkAttachement]
	let sigcaught: [Int32: DispatchSourceSignal]
	var semaphore = AsyncSemaphore(value: 0)
	var vmrunService: VMRunServiceServerProtocol! = nil
	var requestStopFromUIPending = false
	var runningIP: String = ""
	let runMode: Utils.RunMode

	init(location: VMLocation, config: CakeConfig, runMode: Utils.RunMode) throws {
		let suspendable = config.suspendable
		let networks: [any NetworkAttachement] = try config.collectNetworks(runMode: runMode)
		let additionalDiskAttachments = try config.additionalDiskAttachments()
		let directorySharingAttachments = try config.directorySharingAttachments()
		let socketDeviceAttachments = try config.socketDeviceAttachments(agentURL: location.agentURL)
		let consoleURL = try config.consoleAttachment()

		let configuration = VZVirtualMachineConfiguration()
		let plateform = try config.platform(nvramURL: location.nvramURL, needsNestedVirtualization: config.nested)
		let soundDeviceConfiguration = VZVirtioSoundDeviceConfiguration()
		let memoryBallons = VZVirtioTraditionalMemoryBalloonDeviceConfiguration()

		var sigcaught: [Int32: DispatchSourceSignal] = [:]
		var devices: [VZStorageDeviceConfiguration] = [
			VZVirtioBlockDeviceConfiguration(
				attachment: try VZDiskImageStorageDeviceAttachment(
					url: location.diskURL,
					readOnly: false,
					cachingMode: config.os == .linux ? .cached : .automatic,
					synchronizationMode: .full
				))
		]

		let networkDevices = try networks.map {
			let vio = VZVirtioNetworkDeviceConfiguration()

			(vio.macAddress, vio.attachment) = try $0.attachment(location: location, runMode: runMode)

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
			let cdromURL = URL(fileURLWithPath: cloudInitIso, relativeTo: location.diskURL).absoluteURL

			if FileManager.default.fileExists(atPath: cdromURL.path) {
				devices.append(try Self.createCloudInitDrive(cdromURL: cdromURL))
			}
		}

		let communicationDevices = try CommunicationDevices.setup(group: Utilities.group, configuration: configuration, consoleURL: consoleURL, sockets: socketDeviceAttachments)

		try configuration.validate()

		if runMode != .app {
			sigcaught = [SIGINT, SIGUSR1, SIGUSR2].reduce(into: [Int32: DispatchSourceSignal]()) { partialResult, sig in
				partialResult[sig] = DispatchSource.makeSignalSource(signal: sig)
			}
		}

		self.location = location
		self.config = config
		self.runMode = runMode
		self.configuration = configuration
		self.communicationDevices = communicationDevices
		self.networks = networks
		self.sigcaught = sigcaught

		if location.template == false && (config.forwardedPorts.isEmpty == false || config.dynamicPortForwarding) {
			communicationDevices.delegate = self
		}
	}

	func closedByRemote(socket: SocketDevice) {
	}

	func connectionInitiatedByGuest(socket: SocketDevice) {
	}

	func connectionInitiatedByHost(socket: SocketDevice) {
		if socket.bind == self.location.agentURL.path {
			do {
				try PortForwardingServer.createPortForwardingServer(
					group: Utilities.group.next(), name: self.location.name, remoteAddress: self.runningIP, forwardedPorts: self.config.forwardedPorts, dynamicPortForwarding: config.dynamicPortForwarding, listeningAddress: self.location.agentURL,
					runMode: runMode)
			} catch {
				Logger(self).error(error)
			}
		}
	}

	func startCommunicationDevices(_ virtualMachine: VZVirtualMachine) {
		if let communicationDevices = self.communicationDevices {
			communicationDevices.connect(virtualMachine: virtualMachine)
			Logger(self).info("Communication devices \(self.location.name) connected")
		}
	}

	func stopCommunicationDevices() {
		if let communicationDevices = self.communicationDevices {
			Logger(self).info("Close communication devices for VM \(self.location.name)")
			communicationDevices.close()
		}
	}

	func stopForwaringPorts() {
		try? PortForwardingServer.closeForwardedPort()
	}

	func stopVMRunService() {
		if let service = self.vmrunService {
			Logger(self).info("Stopping mount service for VM \(self.location.name)...")
			service.stop()
		}
	}

	func startVMRunService(_ vm: VirtualMachine) throws {
		self.vmrunService = createVMRunServiceServer(group: Utilities.group.next(), runMode: self.runMode, vm: vm, certLocation: try CertificatesLocation.createAgentCertificats(runMode: self.runMode))
	}

	func serveVMRunService() async throws {
		defer {
			self.stopVMRunService()
			self.stopNetworkDevices()
		}

		do {
			self.vmrunService.serve()
			try await self.semaphore.waitUnlessCancelled()
		} catch is CancellationError {
		}
	}

	func stopNetworkDevices() {
		self.networks.forEach { $0.stop(runMode: runMode) }
	}

	func stopServices() {
		stopCommunicationDevices()
		stopForwaringPorts()
	}

	func signalStop() {
		Logger(self).info("Signal VM \(self.location.name) stopped...")
		stopServices()

		if self.requestStopFromUIPending == false {
			self.semaphore.signal()
		}

		self.requestStopFromUIPending = true

		if self.runMode == .app {
			try? self.location.deletePID()
		}
	}

	static func createCloudInitDrive(cdromURL: URL) throws -> VZStorageDeviceConfiguration {
		let attachment: VZDiskImageStorageDeviceAttachment = try VZDiskImageStorageDeviceAttachment(
			url: cdromURL,
			readOnly: true,
			cachingMode: .cached,
			synchronizationMode: VZDiskImageSynchronizationMode.none)

		let cdrom = VZVirtioBlockDeviceConfiguration(attachment: attachment)

		cdrom.blockDeviceIdentifier = "CIDATA"

		return cdrom
	}
}

public final class VirtualMachine: NSObject, @unchecked Sendable, VZVirtualMachineDelegate, ObservableObject {
	static func == (lhs: VirtualMachine, rhs: VirtualMachine) -> Bool {
		lhs.location.rootURL == rhs.location.rootURL
	}

	public typealias StartCompletionHandler = (Result<Void, any Error>) -> Void
	public typealias StopCompletionHandler = ((any Error)?) -> Void

	public var virtualMachine: VZVirtualMachine
	public let config: CakeConfig
	public let location: VMLocation
	public var delegate: VirtualMachineDelegate? = nil
	public var vncServer: VNCServer? = nil

	private var env: VirtualMachineEnvironment
	private var vmQueue: DispatchQueue

	public var suspendable: Bool {
		return self.config.suspendable
	}

	public var status: VMLocation.Status {
		if self.env.runMode != .app {
			return self.location.status
		}

		switch self.virtualMachine.state {
		case .running, .starting, .resuming:
			return .running
		case .paused, .pausing:
			return .paused
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

	public init(location: VMLocation, config: CakeConfig, runMode: Utils.RunMode, queue: dispatch_queue_t? = nil) throws {

		if config.arch != Architecture.current() {
			throw ServiceError("Unsupported architecture")
		}

		self.config = config
		self.location = location
		self.env = try VirtualMachineEnvironment(location: location, config: config, runMode: runMode)

		if let queue = queue {
			self.vmQueue = queue
			self.virtualMachine = VZVirtualMachine(configuration: self.env.configuration, queue: queue)
		} else {
			self.vmQueue = DispatchQueue.main
			self.virtualMachine = VZVirtualMachine(configuration: self.env.configuration)
		}

		super.init()

		virtualMachine.delegate = self
	}

	public func getVM() -> VZVirtualMachine {
		return self.virtualMachine
	}

	private func start(completionHandler: StartCompletionHandler? = nil) async throws {
		var resumeVM: Bool = false

		try self.env.startVMRunService(self)

		#if arch(arm64)
			if #available(macOS 14, *) {
				if FileManager.default.fileExists(atPath: location.stateURL.path) {
					Logger(self).info("Restore VM \(self.location.name) snapshot...")

					try await virtualMachine.restoreMachineStateFrom(url: location.stateURL)
					try FileManager.default.removeItem(at: location.stateURL)

					resumeVM = true
				}
			}

			if resumeVM {
				Logger(self).info("Resume VM \(self.location.name)...")
				self.resumeVM(completionHandler: completionHandler)
			} else {
				Logger(self).info("Start VM \(self.location.name)...")
				self.startVM(completionHandler: completionHandler)
			}
		#else
			Logger(self).info("Start VM \(self.location.name)...")
			self.startVM(completionHandler: completionHandler)
		#endif

		try await self.env.serveVMRunService()

		if Task.isCancelled {
			if virtualMachine.state == VZVirtualMachine.State.running {
				Logger(self).info("Stopping VM \(self.location.name)...")
				self.stopVM()
			}
		}

		Logger(self).info("VM \(self.location.name) exited")
	}

	private func startCompletionHandler(result: Result<Void, any Error>, completionHandler: VirtualMachine.StartCompletionHandler? = nil) {
		self.env.requestStopFromUIPending = false

		self.didChangedState()

		switch result {
		case .success:
			Logger(self).info("VM \(self.location.name) started")
			self.env.startCommunicationDevices(self.virtualMachine)
			break
		case .failure(let error):
			Logger(self).error("VM \(self.location.name) failed to start: \(error)")
		}

		if let completionHandler: VirtualMachine.StartCompletionHandler = completionHandler {
			completionHandler(result)
		}
	}

	public func startFromUI() {
		self.vmQueue.async {
			self.virtualMachine.start { result in
				self.startCompletionHandler(result: result) { result in
					if case .success = result {
						guard (try? self.startedVM(on: Utilities.group.next(), runMode: self.env.runMode)) != nil else {
							Logger(self).error("VM \(self.location.name) failed to get primary IP")
							return
						}
					}
				}
			}
		}
	}

	public func restartFromUI() {
		self.vmQueue.async {
			self._stopVM { result in
				self.startFromUI()
			}
		}
	}

	public func startVM(completionHandler: StartCompletionHandler? = nil) {
		self.vmQueue.sync {
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
					try self.env.configuration.validateSaveRestoreSupport()

					self.virtualMachine.pause { result in

						if case let .failure(err) = result {
							Logger(self).error("Failed to pause VM \(self.location.name) \(err)")
							if let completionHandler = completionHandler {
								completionHandler(result)
							}
						} else {
							Logger(self).info("VM \(self.location.name) paused")

							self.env.stopServices()

							self.virtualMachine.saveMachineStateTo(url: self.location.stateURL) { result in
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
						Logger(self).error("Failed to pause VM \(self.location.name) \(err)")
					} else {
						Logger(self).info("VM \(self.location.name) paused")

						self.env.stopServices()
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
		self.vmQueue.sync {
			self._pauseVM(completionHandler: completionHandler)
		}
	}

	public func resumeVM(completionHandler: StartCompletionHandler? = nil) {
		self.vmQueue.sync {
			if self.virtualMachine.canResume {
				Logger(self).info("VM \(self.location.name) can resume")

				self.virtualMachine.resume { result in
					self.startCompletionHandler(result: result, completionHandler: completionHandler)
				}
			}
		}
	}

	private func _stopVM(completionHandler: StopCompletionHandler? = nil) {
		self.virtualMachine.stop { error in
			if let error = error {
				Logger(self).error("VM \(self.location.name) failed to stop, \(error)")
			} else {
				Logger(self).info("VM \(self.location.name) stopped")

				self.location.removePID()
			}

			self.env.stopServices()

			if let completionHandler = completionHandler {
				completionHandler(error)
			}

			self.didChangedState()
		}
	}

	public func stopVM(completionHandler: StopCompletionHandler? = nil) {
		self.vmQueue.sync {
			self._stopVM(completionHandler: completionHandler)
		}
	}

	public func stopFromUI() {
		self.vmQueue.async {
			self._stopVM()
		}
	}

	private func _requestStopVM() throws {
		self.env.requestStopFromUIPending = true

		if self.virtualMachine.canRequestStop {
			Logger(self).info("Requesting stop VM \(self.location.name)...")
			try self.virtualMachine.requestStop()
			self.didChangedState()
		} else if self.virtualMachine.canStop {
			self.virtualMachine.stop { result in
				Logger(self).info("VM \(self.location.name) stopped")

				self.env.stopServices()
				self.didChangedState()

				if self.env.runMode == .app {
					try? self.location.deletePID()
				}
			}
		} else if self.virtualMachine.state == VZVirtualMachine.State.starting {
			Logger(self).error("VM \(self.location.name) can't be stopped")

			if self.env.runMode != .app {
				throw ExitCode(EXIT_FAILURE)
			}
		}
	}

	public func requestStopVM() throws {
		try self.vmQueue.sync {
			try self._requestStopVM()
		}
	}

	public func requestStopFromUI() {
		self.vmQueue.async {
			try? self._requestStopVM()
		}
	}

	public func suspendFromUI() {
		self.vmQueue.async {
			self._pauseVM()
		}
	}

	private func catchUserSignals(_ task: Task<Int32, Never>) {
		self.env.sigcaught[SIGINT]!.setEventHandler {
			task.cancel()
		}

		self.env.sigcaught[SIGUSR1]!.setEventHandler {
			self.pauseVM { result in
				task.cancel()
			}
		}

		self.env.sigcaught[SIGUSR2]!.setEventHandler {
			if self.env.requestStopFromUIPending == false {
				try? self.requestStopVM()
			}
		}

		self.env.sigcaught.forEach { (key: Int32, value: any DispatchSourceSignal) in
			signal(key, SIG_IGN)
			value.activate()
		}
	}

	public func installAgent(timeout: UInt, runMode: Utils.RunMode) async throws -> Bool {
		return try await withCheckedThrowingContinuation { continuation in
			do {
				let response = try self.location.waitIP(on: Utilities.group.next(), config: self.config, wait: 120, runMode: runMode)

				response.whenSuccess { runningIP in
					let config = self.config

					guard let runningIP = runningIP else {
						Logger(self).error("VM \(self.location.name) failed to get primary IP")
						continuation.resume(with: .success(false))
						return
					}

					do {
						config.agent = try self.location.installAgent(config: config, runningIP: runningIP, timeout: timeout, runMode: runMode)
						config.runningIP = runningIP
						config.firstLaunch = false

						try config.save()

						continuation.resume(with: .success(true))
					} catch {
						Logger(self).error("VM \(self.location.name) failed to install agent: \(error)")

						if let err = error as? SSHError {
							continuation.resume(with: .failure(ServiceError(err.kind.description)))
						} else if let err = error as? Socket.Error {
							if err.errorCode == Socket.SOCKET_ERR_GETADDRINFO_FAILED {
								continuation.resume(with: .failure(ServiceError("SSH server not responding")))
							} else {
								continuation.resume(with: .failure(ServiceError("Socket error: \(err.errorCode)")))
							}
						} else {
							continuation.resume(with: .failure(error))
						}
					}
				}

			} catch {
				continuation.resume(with: .failure(error))
			}
		}
	}

	private func startedVM(on: EventLoop, promise: EventLoopPromise<String?>? = nil, runMode: Utils.RunMode) throws -> EventLoopFuture<String?> {

		if self.env.runMode == .app {
			try self.location.writePID()
		}

		let config = self.config
		let response = try self.location.waitIP(on: on, config: config, wait: 120, runMode: runMode)

		response.whenSuccess { runningIP in
			if let promise = promise {
				promise.succeed(runningIP)
			}

			guard let runningIP = runningIP else {
				Logger(self).error("VM \(self.location.name) failed to get primary IP")
				return
			}

			Logger(self).info("VM \(self.location.name) started with primary IP: \(runningIP)")

			self.env.runningIP = runningIP

			if config.agent == false {
				if config.installAgent {
					do {
						config.agent = try self.location.installAgent(config: config, runningIP: runningIP, runMode: runMode)
					} catch {
						Logger(self).error("VM \(self.location.name) failed to install agent: \(error)")
					}
				}
			}

			config.runningIP = runningIP
			config.firstLaunch = false

			if config.agent {
				self.location.vmInfos(runMode: runMode) { result in
					switch result {
					case .failure(let error):
						Logger(self).error("VM \(self.location.name) failed to get vm infos: \(error)")
					case .success(let infos):
						config.osName = infos.osname
						config.osRelease = infos.release
						break
					}

					try? config.save()
					self.didChangedState()
				}
			} else {
				try? config.save()
				self.didChangedState()
			}

		}

		response.whenFailure { error in
			if let promise = promise {
				promise.fail(error)
			}

			self.didChangedState()

			Logger(self).error("VM \(self.location.name) failed to get primary IP: \(error)")
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

			self.location.removePID()

			guard internalCall else {
				Foundation.exit(status)
			}

			return status
		}

		if self.location.template == false && self.env.runMode != .app {
			self.catchUserSignals(task)
		}

		return try self.startedVM(on: on, promise: promise, runMode: self.env.runMode)
	}

	public func guestDidStop(_ virtualMachine: VZVirtualMachine) {
		Logger(self).info("VM \(self.location.name) stopped")
		self.didChangedStateOnStop()
	}

	public func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
		Logger(self).error(error)
		self.didChangedStateOnStop()
	}

	public func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: any Error) {
		Logger(self).error(error)
		self.didChangedStateOnStop()
	}

	func didChangedStateOnStop() {
		self.env.signalStop()
		self.didChangedState()
	}

	func didChangedState() {
		self.vmQueue.async {
			if let delegate = self.delegate {
				delegate.didChangedState(self)
			}
		}
	}
}
