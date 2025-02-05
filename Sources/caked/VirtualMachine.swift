import Foundation
import Virtualization
import Semaphore
import GRPCLib

class VirtualMachine: NSObject, VZVirtualMachineDelegate, ObservableObject {
	@Published var virtualMachine: VZVirtualMachine?

	var name: String
	var config: CakeConfig
	var communicationDevices: CommunicationDevices?
	var configuration: VZVirtualMachineConfiguration?
	var semaphore = AsyncSemaphore(value: 0)
	var vmLocation: VMLocation

	init(vmLocation: VMLocation,
		networks: [NetworkAttachement],
		additionalDiskAttachments: [VZStorageDeviceConfiguration] = [],
		directorySharingAttachments: [VZDirectorySharingDeviceConfiguration] = [],
		socketDeviceAttachments: [SocketDevice] = [],
		consoleURL: URL? = nil,
		nested: Bool = false) throws {

		if let config = vmLocation.config {
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

				vio.attachment = $0.attachment()
				vio.macAddress = config.macAddress!

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
		} else {
			throw ServiceError("Unexpected missing config")
		}
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
		if let virtualMachine = self.virtualMachine {
			#if arch(arm64)
			if #available(macOS 14, *) {
				try configuration!.validateSaveRestoreSupport()

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
			#endif
		}

		return false
	}

	func start() async throws {
		if let virtualMachine = self.virtualMachine {
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
			#endif

			if resumeVM == false {
				Logger.info("Resume VM...")
				try await resume()
			} else {
				Logger.info("Start VM...")
				try await start()
			}
		}
	}

	@MainActor
	private func resume() async throws {
		try await self.virtualMachine!.resume()
	}

	@MainActor
	private func stop() async throws {
		try await self.virtualMachine!.stop()
	}

	@MainActor
	func run() async throws {
		do {
			try await semaphore.waitUnlessCancelled()
		} catch is CancellationError {
		}

		if Task.isCancelled {
			if let virtualMachine = self.virtualMachine {
				if virtualMachine.state == VZVirtualMachine.State.running {
					Logger.info("Stopping VM...")
					try await self.stop()
				}
			}
		}

		if let communicationDevices {
			communicationDevices.close()
		}
	}

	func catchSIGINT(_ task: Task<Void, Error>) {
		let sig: any DispatchSourceSignal = DispatchSource.makeSignalSource(signal: SIGINT)

		sig.setEventHandler {
			task.cancel()
		}

		sig.activate()
	}

	func catchSIGUSR1(_ task: Task<Void, Error>) {
		signal(SIGUSR1, SIG_IGN)
		
		let sig = DispatchSource.makeSignalSource(signal: SIGUSR1)
		
		sig.setEventHandler {
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
			Task {
				Logger.info("Request guest OS to stop...")
				try self.virtualMachine!.requestStop()
			}
		}

		sig.activate()
	}
}
