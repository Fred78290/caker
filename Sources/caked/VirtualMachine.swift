import Foundation
import Virtualization
import Semaphore
import GRPCLib
import NIO

class VirtualMachineDelegate: NSObject, VZVirtualMachineDelegate, ObservableObject {
	var semaphore = AsyncSemaphore(value: 0)

	func guestDidStop(_ virtualMachine: VZVirtualMachine) {
		Logger.info("VM stopped")

		semaphore.signal()
	}

	func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
		Logger.error(error)

		semaphore.signal()
	}

	func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: any Error) {
		Logger.error(error)

		semaphore.signal()
	}
}

final class VirtualMachine: NSObject, VZVirtualMachineDelegate, ObservableObject {
	private let virtualMachine: VZVirtualMachine
	private let config: CakeConfig
	private let communicationDevices: CommunicationDevices?
	private let configuration: VZVirtualMachineConfiguration
	private let vmLocation: VMLocation
	private let delegate = VirtualMachineDelegate()
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

	init(vmLocation: VMLocation, config: CakeConfig) throws {

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

		let communicationDevices = try CommunicationDevices.setup(configuration: configuration, consoleURL: consoleURL, sockets: socketDeviceAttachments)

		try configuration.validate()

		let virtualMachine = VZVirtualMachine(configuration: configuration)

		self.config = config
		self.vmLocation = vmLocation
		self.configuration = configuration
		self.communicationDevices = communicationDevices
		self.virtualMachine = virtualMachine

		communicationDevices.connect(virtualMachine: virtualMachine)

		super.init()

		virtualMachine.delegate = self.delegate
	}

	public func getVM() -> VZVirtualMachine {
		return self.virtualMachine
	}

	private func pause() async throws -> Bool{
		#if arch(arm64)
			if #available(macOS 14, *) {
				try configuration.validateSaveRestoreSupport()

				Logger.info("Pause VM \(self.vmLocation.name)...")
				try await virtualMachine.pause()

				Logger.info("Create a snapshot of VM \(self.vmLocation.name)...")
				try await virtualMachine.saveMachineStateTo(url: vmLocation.stateURL)

				Logger.info("Snap created successfully...")

				return true
			} else {
				Logger.warn("Snapshot is only supported on macOS 14 or newer")
				Foundation.exit(1)
			}
		#else
			return false
		#endif
	}

	typealias StartCompletionHandler = (Result<Void, any Error>) -> Void

	private func start(completionHandler: StartCompletionHandler? = nil) async throws {
		var resumeVM: Bool = false

		#if arch(arm64)
			if #available(macOS 14, *) {
				if FileManager.default.fileExists(atPath: vmLocation.stateURL.path) {
					Logger.info("Restore VM \(self.vmLocation.name) snapshot...")

					try await virtualMachine.restoreMachineStateFrom(url: vmLocation.stateURL)
					try FileManager.default.removeItem(at: vmLocation.stateURL)

					resumeVM = true
				}
			}
			if resumeVM {
				Logger.info("Resume VM \(self.vmLocation.name)...")
				try await self.resumeVM()
			} else {
				Logger.info("Start VM \(self.vmLocation.name)...")
				try await self.startVM()
			}
		#else
			Logger.info("Start VM \(self.vmLocation.name)...")
			try await self.startVM()
		#endif
	}

	@MainActor
	public func startVM(completionHandler: StartCompletionHandler? = nil) async throws {
		if let completionHandler = completionHandler {
			self.virtualMachine.start(completionHandler: completionHandler)
		} else {
			try await self.virtualMachine.start()
		}
	}

	@MainActor
	public func resumeVM(completionHandler: StartCompletionHandler? = nil) async throws {
		if let completionHandler = completionHandler {
			self.virtualMachine.resume(completionHandler: completionHandler)
		} else {
			try await self.virtualMachine.resume()
		}
	}

	public func stopVM() async throws {
		try await self.virtualMachine.stop()
	}

	public func requestStopVM() throws {
		try self.virtualMachine.requestStop()
	}

	@MainActor
	private func run() async throws {
		defer {
			if let id = self.identifier {
				try? PortForwardingServer.closeForwardedPort(identifier: id)
				self.setIdentifier(nil)
			}

			if let communicationDevices = self.communicationDevices {
				communicationDevices.close()
			}
		}

		do {
			try await delegate.semaphore.waitUnlessCancelled()
		} catch is CancellationError {
		}

		if Task.isCancelled {
			if virtualMachine.state == VZVirtualMachine.State.running {
				Logger.info("Stopping VM \(self.vmLocation.name)...")
				try await self.stopVM()
			}
		}

		Logger.info("VM \(self.vmLocation.name) exited")
	}

	private func catchSIGINT(_ task: Task<Int32, Never>) {
		signal(SIGINT, SIG_IGN)
		let sig: any DispatchSourceSignal = DispatchSource.makeSignalSource(signal: SIGINT)

		sig.setEventHandler {
			Logger.info("Receive SIGINT")

			task.cancel()
		}

		sig.activate()
	}

	private func catchSIGUSR1(_ task: Task<Int32, Never>) {
		signal(SIGUSR1, SIG_IGN)

		let sig = DispatchSource.makeSignalSource(signal: SIGUSR1)

		sig.setEventHandler {
			Logger.info("Receive SIGUSR1")

			Task {
				do {
					if try await self.pause() {
						task.cancel()
					}
				} catch {
					Logger.error(error)

					Foundation.exit(1)
				}
			}
		}

		sig.activate()
	}

	private func catchSIGUSR2(_ task: Task<Int32, Never>) {
		signal(SIGUSR2, SIG_IGN)

		let sig = DispatchSource.makeSignalSource(signal: SIGUSR1)

		sig.setEventHandler {
			Logger.info("Receive SIGUSR1")

			Task {
				Logger.info("Request guest OS to stop...")
				try self.virtualMachine.requestStop()
			}
		}

		sig.activate()
	}

	private func catchUserSignals(_ task: Task<Int32, Never>) {
		self.catchSIGINT(task)
		self.catchSIGUSR1(task)
		self.catchSIGUSR2(task)
	}

	func waitIP(on: EventLoop, wait: Int, asSystem: Bool) throws -> String? {
		let listeningAddress = vmLocation.agentURL
		let certLocation = try CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem))).createCertificats()
		let conn = CakeAgentConnection(eventLoop: on, listeningAddress: listeningAddress, certLocation: certLocation, timeout: 10, retries: .unlimited)

		let start: Date = Date.now
		var count = 0

		repeat {
			if let infos = try? conn.info() {
				if let runningIP = infos.ipaddresses.first {
					return runningIP
				}
			}
			count += 1
		} while Date.now.timeIntervalSince(start) < TimeInterval(wait)

		Logger.warn("Unable to get IP for VM \(self.vmLocation.name)")

		return nil
	}

	func runInBackground(on: EventLoop) throws -> EventLoopFuture<String?> {
		let task = Task {
			var status: Int32 = 0

			do {
				try await self.start()
				try await self.run()
			} catch {
				status = 1
			}

			self.vmLocation.removePID()

			if self.vmLocation.template == false {
				Foundation.exit(status)
			}

			return status
		}

		if self.vmLocation.template == false {
			self.catchUserSignals(task)
		}

		return on.makeFutureWithTask {
			let config: CakeConfig = self.config

			guard let runningIP = try? self.waitIP(on: on.next(), wait: 60, asSystem: runAsSystem) else {
				return nil
			}

			Logger.info("VM \(self.vmLocation.name) started with primary IP: \(runningIP)")

			if self.vmLocation.template == false {

				if config.forwardedPorts.isEmpty == false {
					Logger.info("Forwarding ports from \(runningIP)")

					PortForwardingServer.createPortForwardingServer(on: on.next())

					self.setIdentifier(try PortForwardingServer.createForwardedPort(remoteHost: runningIP, forwardedPorts: self.config.forwardedPorts))
				}
			}

			return runningIP
		}
	}
}
