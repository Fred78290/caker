import Foundation
import Virtualization
import Semaphore
import GRPCLib
import NIO

final class VirtualMachine: NSObject, VZVirtualMachineDelegate, ObservableObject {
	var virtualMachine: VZVirtualMachine
	var name: String
	var config: CakeConfig
	var communicationDevices: CommunicationDevices?
	var configuration: VZVirtualMachineConfiguration
	var semaphore = AsyncSemaphore(value: 0)
	var vmLocation: VMLocation

	init(vmLocation: VMLocation,
	     networks: [NetworkAttachement],
	     additionalDiskAttachments: [VZStorageDeviceConfiguration] = [],
	     directorySharingAttachments: [VZDirectorySharingDeviceConfiguration] = [],
	     socketDeviceAttachments: [SocketDevice] = [],
	     consoleURL: URL? = nil,
	     nested: Bool = false) throws {

		let config = try vmLocation.config()

		if config.arch != Architecture.current() {
			throw ServiceError("Unsupported architecture")
		}

		let configuration = VZVirtualMachineConfiguration()
		let plateform = try config.platform(nvramURL: vmLocation.nvramURL, needsNestedVirtualization: nested)
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
		self.name = vmLocation.name
		self.config = config
		self.configuration = configuration
		self.communicationDevices = communicationDevices
		self.virtualMachine = virtualMachine

		communicationDevices.connect(virtualMachine: virtualMachine)

		super.init()

		virtualMachine.delegate = self
	}

	static func createCloudInitDrive(cdromURL: URL) throws -> VZStorageDeviceConfiguration {
		let attachment: VZDiskImageStorageDeviceAttachment = try VZDiskImageStorageDeviceAttachment(url: cdromURL,
		                                                                                            readOnly: true,
		                                                                                            cachingMode: .cached,
		                                                                                            synchronizationMode: VZDiskImageSynchronizationMode.none)

		let cdrom = VZVirtioBlockDeviceConfiguration(attachment: attachment)

		cdrom.blockDeviceIdentifier = "CIDATA"

		return cdrom
	}

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

	func pause() async throws -> Bool{
		#if arch(arm64)
			if #available(macOS 14, *) {
				try configuration.validateSaveRestoreSupport()

				Logger.info("Pause VM...")
				try await virtualMachine.pause()

				Logger.info("Create a snapshot...")
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

	func start() async throws {
		var resumeVM: Bool = false

		#if arch(arm64)
			if #available(macOS 14, *) {
				if FileManager.default.fileExists(atPath: vmLocation.stateURL.path) {
					Logger.info("Restore VM snapshot...")

					try await virtualMachine.restoreMachineStateFrom(url: vmLocation.stateURL)
					try FileManager.default.removeItem(at: vmLocation.stateURL)

					resumeVM = true
				}
			}
			if resumeVM {
				Logger.info("Resume VM...")
				try await resume()
			} else {
				Logger.info("Start VM...")
				try await self.startVM()
			}
		#else
			Logger.info("Start VM...")
			try await self.startVM()
		#endif
	}

	@MainActor
	private func startVM() async throws {
		try await self.virtualMachine.start()
	}

	@MainActor
	private func resume() async throws {
		try await self.virtualMachine.resume()
	}

	@MainActor
	private func stop() async throws {
		try await self.virtualMachine.stop()
	}

	@MainActor
	func run() async throws {
		var identifier: String? = nil

		if config.forwardedPorts.isEmpty == false {
			let runningIP: String = try await waitIP(wait: 120, asSystem: runAsSystem)

			Logger.info("Forwarding ports from \(runningIP)")

			PortForwardingServer.createPortForwardingServer(on: Root.group)

			identifier = try PortForwardingServer.createForwardedPort(remoteHost: runningIP, forwardedPorts: config.forwardedPorts)
		}

		defer {
			if let id = identifier {
				try? PortForwardingServer.closeForwardedPort(identifier: id)
			}

			if let communicationDevices {
				communicationDevices.close()
			}
		}

		do {
			try await semaphore.waitUnlessCancelled()
		} catch is CancellationError {
		}

		if Task.isCancelled {
			if virtualMachine.state == VZVirtualMachine.State.running {
				Logger.info("Stopping VM...")
				try await self.stop()
			}
		}

		Logger.info("VM exited")
	}

	func catchSIGINT(_ task: Task<Void, Error>) {
		let sig: any DispatchSourceSignal = DispatchSource.makeSignalSource(signal: SIGINT)

		sig.setEventHandler {
			Logger.info("Receive SIGINT")

			task.cancel()
		}

		sig.activate()
	}

	func catchSIGUSR1(_ task: Task<Void, Error>) {
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

	func catchSIGUSR2(_ task: Task<Void, Error>) {
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

	func catchUserSignals(_ task: Task<Void, Error>) {
		self.catchSIGINT(task)
		self.catchSIGUSR1(task)
		self.catchSIGUSR2(task)
	}

	private func waitIP(wait: Int, asSystem: Bool) async throws -> String {
		let listeningAddress = vmLocation.agentURL
		let certLocation = try CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem))).createCertificats()
		let conn = CakeAgentConnection(eventLoop: Root.group.any(), listeningAddress: listeningAddress, certLocation: certLocation, timeout: 10, retries: .unlimited)

		let start: Date = Date.now
		var count = 0

		repeat {
			if let infos = try? await conn.info() {
				if let runningIP = infos.ipaddresses.first {
					return runningIP
				}
			}
			count += 1
		} while Date.now.timeIntervalSince(start) < TimeInterval(wait)

		Logger.warn("Unable to get IP for VM \(name)")

		return ""
	}
}
