import Foundation
import Virtualization
import Semaphore
import GRPCLib
import NIO
import NIOPortForwarding

final class VirtualMachine: NSObject, VZVirtualMachineDelegate, ObservableObject {
	public typealias StartCompletionHandler = (Result<Void, any Error>) -> Void
	public typealias StopCompletionHandler = ((any Error)?) -> Void

	public let virtualMachine: VZVirtualMachine
	public let config: CakeConfig
	public let vmLocation: VMLocation

	private let communicationDevices: CommunicationDevices?
	private let configuration: VZVirtualMachineConfiguration
	private let sigint: DispatchSourceSignal
	private let sigusr1: DispatchSourceSignal
	private let sigusr2: DispatchSourceSignal
	private var semaphore = AsyncSemaphore(value: 0)
	private var identifier: String?
	private func setIdentifier(_ id: String?) {
		self.identifier = id
	}

	private static func createCloudInitDrive(cdromURL: URL) throws -> VZStorageDeviceConfiguration {
		let attachment: VZDiskImageStorageDeviceAttachment = try VZDiskImageStorageDeviceAttachment(url: cdromURL,
		                                                                                            readOnly: true,
		                                                                                            cachingMode: .cached,
		                                                                                            synchronizationMode: VZDiskImageSynchronizationMode.none)

		let cdrom = VZVirtioBlockDeviceConfiguration(attachment: attachment)

		cdrom.blockDeviceIdentifier = "CIDATA"

		return cdrom
	}

	public init(vmLocation: VMLocation, config: CakeConfig) throws {

		if config.arch != Architecture.current() {
			throw ServiceError("Unsupported architecture")
		}

		let networks: [any NetworkAttachement] = try config.collectNetworks()
		let additionalDiskAttachments = try config.additionalDiskAttachments()
		let directorySharingAttachments = try config.directorySharingAttachments()
		let socketDeviceAttachments = try config.socketDeviceAttachments()
		let consoleURL = try config.consoleAttachment()

		let configuration = VZVirtualMachineConfiguration()
		let plateform = try config.platform(nvramURL: vmLocation.nvramURL, needsNestedVirtualization: config.nested)
		let soundDeviceConfiguration = VZVirtioSoundDeviceConfiguration()
		let memoryBallons = VZVirtioTraditionalMemoryBalloonDeviceConfiguration()

		var devices: [VZStorageDeviceConfiguration] = [VZVirtioBlockDeviceConfiguration(attachment: try VZDiskImageStorageDeviceAttachment(
			url: vmLocation.diskURL,
			readOnly: false,
			cachingMode: config.os == .linux ? .cached : .automatic,
			synchronizationMode: .full
		))]

		let networkDevices = networks.map {
			let vio = VZVirtioNetworkDeviceConfiguration()

			(vio.macAddress, vio.attachment) = $0.attachment()

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
		configuration.keyboards = plateform.keyboards()
		configuration.pointingDevices = plateform.pointingDevices()
		configuration.networkDevices = networkDevices
		configuration.storageDevices = devices
		configuration.directorySharingDevices = directorySharingAttachments
		configuration.serialPorts = []
		configuration.memoryBalloonDevices = [memoryBallons]

		if config.os == .linux {
			let spiceAgentConsoleDevice = VZVirtioConsoleDeviceConfiguration()
			let spiceAgentPort = VZVirtioConsolePortConfiguration()

			spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
			spiceAgentPort.attachment = VZSpiceAgentPortAttachment()
			spiceAgentConsoleDevice.ports[0] = spiceAgentPort

			configuration.consoleDevices.append(spiceAgentConsoleDevice)

			let cdromURL = URL(fileURLWithPath: "cloud-init.iso", relativeTo: vmLocation.diskURL).absoluteURL

			if FileManager.default.fileExists(atPath: cdromURL.path()) {
				devices.append(try Self.createCloudInitDrive(cdromURL: cdromURL))
			}
		}

		let communicationDevices = try CommunicationDevices.setup(group: Root.group, configuration: configuration, consoleURL: consoleURL, sockets: socketDeviceAttachments)

		try configuration.validate()

		let virtualMachine = VZVirtualMachine(configuration: configuration)

		self.config = config
		self.vmLocation = vmLocation
		self.configuration = configuration
		self.communicationDevices = communicationDevices
		self.virtualMachine = virtualMachine

		signal(SIGINT, SIG_IGN)
		signal(SIGUSR1, SIG_IGN)
		signal(SIGUSR2, SIG_IGN)

		self.sigint = DispatchSource.makeSignalSource(signal: SIGINT)
		self.sigusr1 = DispatchSource.makeSignalSource(signal: SIGUSR1)
		self.sigusr2 = DispatchSource.makeSignalSource(signal: SIGUSR2)

		super.init()

		virtualMachine.delegate = self
	}

	public func getVM() -> VZVirtualMachine {
		return self.virtualMachine
	}

	private func pause() async throws -> Bool{
		#if arch(arm64)
			if #available(macOS 14, *) {
				try configuration.validateSaveRestoreSupport()

				Logger(self).info("Pause VM \(self.vmLocation.name)...")
				try await virtualMachine.pause()

				Logger(self).info("Create a snapshot of VM \(self.vmLocation.name)...")
				try await virtualMachine.saveMachineStateTo(url: vmLocation.stateURL)

				Logger(self).info("Snap created successfully...")

				return true
			} else {
				Logger(self).warn("Snapshot is only supported on macOS 14 or newer")
				Foundation.exit(1)
			}
		#else
			return false
		#endif
	}

	private func start(completionHandler: StartCompletionHandler? = nil) async throws {
		var resumeVM: Bool = false
		let mountService = createMountServiceServer(group: Root.group.next(), asSystem: runAsSystem, vm: self, certLocation: try CertificatesLocation.createAgentCertificats(asSystem: runAsSystem))

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
			mountService.stop()
			if let id = self.identifier {
				try? PortForwardingServer.closeForwardedPort(identifier: id)
				self.setIdentifier(nil)
			}
		}

		do {
			mountService.serve()
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

	public func startFromUI() {
		self.virtualMachine.start{ result in
			switch result {
			case .success:
				Logger(self).info("VM \(self.vmLocation.name) started")
				if let communicationDevices = self.communicationDevices {
					communicationDevices.connect(virtualMachine: self.virtualMachine)
					Logger(self).info("Communication devices \(self.vmLocation.name) connected")
				}
				break
			case .failure(let error):
				Logger(self).error("VM \(self.vmLocation.name) failed to start: \(error)")
			}
		}
	}

	public func startVM(completionHandler: StartCompletionHandler? = nil) {
		DispatchQueue.main.sync {
			self.virtualMachine.start{ result in
				switch result {
				case .success:
					Logger(self).info("VM \(self.vmLocation.name) started")
					if let communicationDevices = self.communicationDevices {
						communicationDevices.connect(virtualMachine: self.virtualMachine)
						Logger(self).info("Communication devices \(self.vmLocation.name) connected")
					}
					break
				case .failure(let error):
					Logger(self).error("VM \(self.vmLocation.name) failed to start: \(error)")
				}

				if let completionHandler = completionHandler {
					completionHandler(result)
				}
			}
		}
	}

	public func resumeVM(completionHandler: StartCompletionHandler? = nil) {
		DispatchQueue.main.sync {
			self.virtualMachine.resume { result in
				switch result {
				case .success:
					Logger(self).info("VM \(self.vmLocation.name) resumed")
					if let communicationDevices = self.communicationDevices {
						communicationDevices.connect(virtualMachine: self.virtualMachine)
					}
					break
				case .failure(let error):
					Logger(self).error("VM \(self.vmLocation.name) failed to resume: \(error)")
				}

				if let completionHandler = completionHandler {
					completionHandler(result)
				}
			}
		}
	}

	public func stopFromUI() {
		self.virtualMachine.stop { result in
			Logger(self).info("VM \(self.vmLocation.name) stopped")

			self.closeCommunicationDevices()
		}
	}

	public func stopVM(completionHandler: StopCompletionHandler? = nil) {
		DispatchQueue.main.sync {
			self.virtualMachine.stop { result in
				Logger(self).info("VM \(self.vmLocation.name) stopped")

				self.closeCommunicationDevices()

				if let completionHandler = completionHandler {
					completionHandler(result)
				}
			}
		}
	}

	public func requestStopFromUI() throws {
		try self.virtualMachine.requestStop()
	}

	public func requestStopVM() throws {
		try DispatchQueue.main.sync {
			try self.virtualMachine.requestStop()
		}
	}

	private func signalStop() {
		closeCommunicationDevices()

		self.semaphore.signal()
	}

	private func closeCommunicationDevices() {
		if let communicationDevices = self.communicationDevices {
			Logger(self).info("Close communication devices for VM \(self.vmLocation.name)")
			communicationDevices.close()
		}
	}

	private func catchUserSignals(_ task: Task<Int32, Never>) {
		sigint.setEventHandler {
			task.cancel()
		}

		sigusr1.setEventHandler {
			Task {
				do {
					if try await self.pause() {
						task.cancel()
					}
				} catch {
					Logger(self).error(error)

					Foundation.exit(1)
				}
			}
		}

		sigusr2.setEventHandler {
			Task {
				Logger(self).info("Request guest OS to stop...")
				try self.virtualMachine.requestStop()
			}
		}

		sigint.activate()
		sigusr1.activate()
		sigusr2.activate()
	}

	public func runInBackground(on: EventLoop, internalCall: Bool, asSystem: Bool, promise: EventLoopPromise<String?>? = nil, completionHandler: StartCompletionHandler? = nil) throws -> EventLoopFuture<String?> {
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

		if self.vmLocation.template == false {
			self.catchUserSignals(task)
		}

		let config = self.config
		let response = try self.vmLocation.waitIP(on: on, config: config, wait: 120, asSystem: asSystem)

		response.whenSuccess { runningIP in
			if let promise = promise {
				promise.succeed(runningIP)
			}

			guard let runningIP = runningIP else {
				Logger(self).error("VM \(self.vmLocation.name) failed to get primary IP")
				return
			}

			Logger(self).info("VM \(self.vmLocation.name) started with primary IP: \(runningIP)")

			if config.firstLaunch && config.agent == false {
				do {
					config.agent = try self.vmLocation.installAgent(config: config, runningIP: runningIP)
				} catch {
					Logger(self).error("VM \(self.vmLocation.name) failed to install agent: \(error)")
				}
			}

			config.runningIP = runningIP
			config.firstLaunch = false

			try? config.save()

			if self.vmLocation.template == false {
				if config.forwardedPorts.isEmpty == false {
					Logger(self).info("Configure forwarding ports for VM \(self.vmLocation.name)")

					PortForwardingServer.createPortForwardingServer(group: on.next())

					if let identifier = try? PortForwardingServer.createForwardedPort(remoteHost: runningIP, forwardedPorts: self.config.forwardedPorts) {
						self.setIdentifier(identifier)
					}
				}
			}
		}

		response.whenFailure { error in
			if let promise = promise {
				promise.fail(error)
			}

			Logger(self).error("VM \(self.vmLocation.name) failed to get primary IP: \(error)")
		}
		return response
	}

	func guestDidStop(_ virtualMachine: VZVirtualMachine) {
		Logger(self).info("VM \(self.vmLocation.name) stopped")

		self.signalStop()
	}

	func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
		Logger(self).error(error)

		self.signalStop()
	}

	func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: any Error) {
		Logger(self).error(error)

		self.signalStop()
	}
}
