import Foundation
import GRPCLib
import NIO
import NIOPortForwarding
import Semaphore
import SwiftUI
import UniformTypeIdentifiers
import Virtualization

extension UTType {
	static var VirtualMachine: UTType {
		UTType(importedAs: "com.aldunelabs.caker.caked-vm")
	}
}

final class VirtualMachine: NSObject, VZVirtualMachineDelegate, ObservableObject, FileDocument, VirtioSocketDeviceDelegate {
	static var readableContentTypes: [UTType] { [.VirtualMachine] }

	public typealias StartCompletionHandler = (Result<Void, any Error>) -> Void
	public typealias StopCompletionHandler = ((any Error)?) -> Void

	public var virtualMachine: VZVirtualMachine?
	public var config: CakeConfig?
	public let vmLocation: VMLocation

	private let communicationDevices: CommunicationDevices?
	private let configuration: VZVirtualMachineConfiguration
	private let networks: [NetworkAttachement]
	private let sigcaught: [Int32: DispatchSourceSignal]
	private var semaphore = AsyncSemaphore(value: 0)
	private var mountService: MountServiceServerProtocol? = nil
	private var requestStopFromUIPending = false
	private var runningIP: String = ""
	private let asSystem: Bool

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

	override init() {
		let configuration = VZVirtualMachineConfiguration()
		let vmLocation = StorageLocation(asSystem: false).location("default")

		self.asSystem = false
		self.config = nil
		self.vmLocation = vmLocation
		self.configuration = configuration
		self.communicationDevices = nil
		self.virtualMachine = nil
		self.networks = []
		self.sigcaught = [:]
	}

	init(configuration: ReadConfiguration) throws {
		if configuration.file.isDirectory {

		}

		throw ServiceError("Not a VM")
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let data = "none".data(using: .utf8)!
		return .init(regularFileWithContents: data)
	}

	public init(vmLocation: VMLocation, config: CakeConfig, asSystem: Bool) throws {

		if config.arch != Architecture.current() {
			throw ServiceError("Unsupported architecture")
		}

		let networks: [any NetworkAttachement] = try config.collectNetworks(asSystem: asSystem)
		let additionalDiskAttachments = try config.additionalDiskAttachments()
		let directorySharingAttachments = try config.directorySharingAttachments()
		let socketDeviceAttachments = try config.socketDeviceAttachments(agentURL: vmLocation.agentURL)
		let consoleURL = try config.consoleAttachment()

		let configuration = VZVirtualMachineConfiguration()
		let plateform = try config.platform(nvramURL: vmLocation.nvramURL, needsNestedVirtualization: config.nested)
		let soundDeviceConfiguration = VZVirtioSoundDeviceConfiguration()
		let memoryBallons = VZVirtioTraditionalMemoryBalloonDeviceConfiguration()

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

			(vio.macAddress, vio.attachment) = try $0.attachment(vmLocation: vmLocation, asSystem: asSystem)

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

		let spiceAgentConsoleDevice = VZVirtioConsoleDeviceConfiguration()
		let spiceAgentPort = VZVirtioConsolePortConfiguration()
		let spiceAgentPortAttachment = VZSpiceAgentPortAttachment()

		spiceAgentPortAttachment.sharesClipboard = true

		spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
		spiceAgentPort.attachment = spiceAgentPortAttachment
		spiceAgentConsoleDevice.ports[0] = spiceAgentPort
		configuration.consoleDevices.append(spiceAgentConsoleDevice)

		if config.os == .linux {
			let cdromURL = URL(fileURLWithPath: "cloud-init.iso", relativeTo: vmLocation.diskURL).absoluteURL

			if FileManager.default.fileExists(atPath: cdromURL.path) {
				devices.append(try Self.createCloudInitDrive(cdromURL: cdromURL))
			}
		}

		let communicationDevices = try CommunicationDevices.setup(group: Root.group, configuration: configuration, consoleURL: consoleURL, sockets: socketDeviceAttachments)

		try configuration.validate()

		let virtualMachine = VZVirtualMachine(configuration: configuration)

		self.asSystem = asSystem
		self.config = config
		self.vmLocation = vmLocation
		self.configuration = configuration
		self.communicationDevices = communicationDevices
		self.virtualMachine = virtualMachine
		self.networks = networks
		self.sigcaught = [SIGINT, SIGUSR1, SIGUSR2].reduce(into: [Int32: DispatchSourceSignal]()) { partialResult, sig in
			partialResult[sig] = DispatchSource.makeSignalSource(signal: sig)
		}

		super.init()

		if vmLocation.template == false && (config.forwardedPorts.isEmpty == false || config.dynamicPortFarwarding) {
			communicationDevices.delegate = self
		}

		virtualMachine.delegate = self
	}

	public func getVM() -> VZVirtualMachine? {
		return self.virtualMachine
	}

	private func pause() async throws -> Bool {
		if let virtualMachine = self.virtualMachine {
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
					throw ExitCode(EXIT_FAILURE)
				}
			#else
				return false
			#endif

		}

		return false
	}

	private func start(completionHandler: StartCompletionHandler? = nil) async throws {
		guard let virtualMachine = self.virtualMachine else {
			return
		}

		var resumeVM: Bool = false

		self.mountService = createMountServiceServer(group: Root.group.next(), asSystem: self.asSystem, vm: self, certLocation: try CertificatesLocation.createAgentCertificats(asSystem: self.asSystem))

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
		if let virtualMachine = self.virtualMachine {
			virtualMachine.start { result in
				self.startCompletionHandler(result: result) { result in
					if case .success = result {
						guard (try? self.startedVM(on: Root.group.next(), asSystem: false)) != nil else {
							Logger(self).error("VM \(self.vmLocation.name) failed to get primary IP")
							return
						}
					}
				}
			}
		}
	}

	public func startVM(completionHandler: StartCompletionHandler? = nil) {
		if let virtualMachine = self.virtualMachine {
			DispatchQueue.main.sync {
				virtualMachine.start { result in
					self.startCompletionHandler(result: result, completionHandler: completionHandler)
				}
			}
		}
	}

	public func resumeVM(completionHandler: StartCompletionHandler? = nil) {
		if let virtualMachine = self.virtualMachine {
			DispatchQueue.main.sync {
				virtualMachine.resume { result in
					self.startCompletionHandler(result: result, completionHandler: completionHandler)
				}
			}
		}
	}

	public func stopFromUI() {
		if let virtualMachine = self.virtualMachine {
			virtualMachine.stop { result in
				Logger(self).info("VM \(self.vmLocation.name) stopped")

				self.stopServices()
			}
		}
	}

	public func stopVM(completionHandler: StopCompletionHandler? = nil) {
		if let virtualMachine = self.virtualMachine {
			DispatchQueue.main.sync {
				virtualMachine.stop { result in
					Logger(self).info("VM \(self.vmLocation.name) stopped")

					self.stopServices()

					if let completionHandler = completionHandler {
						completionHandler(result)
					}
				}
			}
		}
	}

	public func requestStopFromUI() throws {
		if let virtualMachine = self.virtualMachine {
			self.requestStopFromUIPending = true
			try virtualMachine.requestStop()
		}
	}

	public func requestStopVM() throws {
		if let virtualMachine = self.virtualMachine {
			try DispatchQueue.main.sync {
				if virtualMachine.canRequestStop {
					Logger(self).info("Requesting stop VM \(self.vmLocation.name)...")
					try virtualMachine.requestStop()
				} else if virtualMachine.canStop {
					virtualMachine.stop { result in
						Logger(self).info("VM \(self.vmLocation.name) stopped")

						self.stopServices()
					}
				} else {
					Logger(self).error("VM \(self.vmLocation.name) can't be stopped")

					if virtualMachine.state == VZVirtualMachine.State.starting {
						throw ExitCode(EXIT_FAILURE)
					}
				}
			}
		}
	}

	private func startCommunicationDevices() {
		if let communicationDevices = self.communicationDevices {
			communicationDevices.connect(virtualMachine: self.virtualMachine!)
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
		self.networks.forEach { $0.stop(asSystem: asSystem) }
	}

	private func stopServices() {
		stopCommunicationDevices()
		stopForwaringPorts()
	}

	private func catchUserSignals(_ task: Task<Int32, Never>) {
		sigcaught[SIGINT]?.setEventHandler {
			task.cancel()
		}

		sigcaught[SIGUSR1]?.setEventHandler {
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

		sigcaught[SIGUSR2]?.setEventHandler {
			try? self.requestStopVM()
		}

		sigcaught.forEach { (key: Int32, value: any DispatchSourceSignal) in
			signal(key, SIG_IGN)
			value.activate()
		}
	}

	private func startedVM(on: EventLoop, promise: EventLoopPromise<String?>? = nil, asSystem: Bool) throws -> EventLoopFuture<String?> {
		if let config = self.config {
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

				self.runningIP = runningIP

				if config.firstLaunch && config.agent == false {
					do {
						config.agent = try self.vmLocation.installAgent(config: config, runningIP: runningIP, asSystem: asSystem)
					} catch {
						Logger(self).error("VM \(self.vmLocation.name) failed to install agent: \(error)")
					}
				}

				config.runningIP = runningIP
				config.firstLaunch = false

				try? config.save()

				//			if self.vmLocation.template == false && (config.forwardedPorts.isEmpty == false || config.dynamicPortFarwarding) {
				//				Logger(self).info("Configure forwarding ports for VM \(self.vmLocation.name)")
				//
				//				do {
				//					try PortForwardingServer.createPortForwardingServer(group: on.next(), remoteAddress: runningIP, forwardedPorts: self.config.forwardedPorts, dynamicPortFarwarding: config.dynamicPortFarwarding, listeningAddress: self.vmLocation.agentURL, asSystem: asSystem)
				//				} catch {
				//					Logger(self).error(error)
				//				}
				//			}
			}

			response.whenFailure { error in
				if let promise = promise {
					promise.fail(error)
				}

				Logger(self).error("VM \(self.vmLocation.name) failed to get primary IP: \(error)")
			}

			return response
		}

		return on.submit {
			nil
		}
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

		if self.vmLocation.template == false {
			self.catchUserSignals(task)
		}

		return try self.startedVM(on: on, promise: promise, asSystem: asSystem)
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

	func closedByRemote(socket: SocketDevice) {
	}

	func connectionInitiatedByGuest(socket: SocketDevice) {
	}

	func connectionInitiatedByHost(socket: SocketDevice) {
		if let config = self.config {
			if socket.bind == self.vmLocation.agentURL.path {
				Logger(self).info("Configure forwarding ports for VM \(self.vmLocation.name)")

				do {
					try PortForwardingServer.createPortForwardingServer(
						group: Root.group.next(), remoteAddress: self.runningIP, forwardedPorts: config.forwardedPorts, dynamicPortFarwarding: config.dynamicPortFarwarding, listeningAddress: self.vmLocation.agentURL, asSystem: asSystem)
				} catch {
					Logger(self).error(error)
				}
			}
		}
	}

}
