//
//  IPSWInstaller.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/07/2025.
//
import Virtualization
import GRPCLib

#if arch(arm64)
public struct IPSWInstaller {
	public enum IPSWProgressValue: Sendable {
		case progress(Double)
		case terminated(Result<Void, any Error>)
	}
	
	public typealias IPSWProgressHandler = (IPSWProgressValue) -> Void
	
	private let virtualMachine: VZVirtualMachine
	private let config: CakeConfig
	private let location: VMLocation
	private let queue: DispatchQueue!
	
	public init(config: CakeConfig, location: VMLocation, runMode: Utils.RunMode, queue: DispatchQueue? = nil) throws {
		let virtualMachine: VZVirtualMachine
		let suspendable = config.suspendable
		let networks: [any NetworkAttachement] = try config.collectNetworks(runMode: runMode)
		let configuration = VZVirtualMachineConfiguration()
		let plateform = try config.platform(nvramURL: location.nvramURL, needsNestedVirtualization: config.nested)
		let soundDeviceConfiguration = VZVirtioSoundDeviceConfiguration()
		let memoryBallons = VZVirtioTraditionalMemoryBalloonDeviceConfiguration()
		
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
				devices.append(try VirtualMachineEnvironment.createCloudInitDrive(cdromURL: cdromURL))
			}
		}
		
		try configuration.validate()
		
		if let queue = queue {
			virtualMachine = VZVirtualMachine(configuration: configuration, queue: queue)
		} else {
			virtualMachine = VZVirtualMachine(configuration: configuration)
		}
		
		self.config = config
		self.location = location
		self.virtualMachine = virtualMachine
		self.queue = queue
	}
	
	@MainActor
	private func installIPSWSync(_ url: URL, progressHandler: IPSWProgressHandler? = nil) async throws {
		let installer = VZMacOSInstaller(virtualMachine: self.virtualMachine, restoringFromImageAt: url)
		let progressObserver = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { progress, change in
			if let progressHandler = progressHandler {
				//progressHandler(.progress(progress.fractionCompleted))
			}
		}
		
		try await withTaskCancellationHandler(operation: {
			try await withCheckedThrowingContinuation { continuation in
				installer.install { result in
					if let progressHandler = progressHandler {
						//progressHandler(.terminated(result))
					}
					continuation.resume(with: result)
					progressObserver.invalidate()
				}
			}
		}, onCancel: {
			installer.progress.cancel()
		})
	}
	
	private func installIPSWAsync(_ url: URL, progressHandler: IPSWProgressHandler? = nil) async throws {
		let vm: () -> VZVirtualMachine = { self.virtualMachine }
		
		try await withCheckedThrowingContinuation { continuation in
			queue.async {
				let installer = VZMacOSInstaller(virtualMachine: vm(), restoringFromImageAt: url)
				let progressObserver = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { progress, change in
					print("[\(Thread.current.description)] install progress \(progress.fractionCompleted)")
					if let progressHandler = progressHandler {
						progressHandler(.progress(progress.fractionCompleted))
					}
					print("[\(Thread.current.description)] leave progress \(progress.fractionCompleted)")
				}
				
				print("[\(Thread.current.description)] start install")
				installer.install { result in
					print("[\(Thread.current.description)] install terminated")
					if let progressHandler = progressHandler {
						progressHandler(.terminated(result))
					}
					continuation.resume(with: result)
					progressObserver.invalidate()
				}
				print("[\(Thread.current.description)] exiting install")
			}
		}
		
		print("[\(Thread.current.description)] exiting installIPSW")
	}
	
	public func installIPSW(_ url: URL, progressHandler: IPSWProgressHandler? = nil) async throws {
		if self.queue == nil {
			try await self.installIPSWSync(url, progressHandler: progressHandler)
		} else {
			try await self.installIPSWAsync(url, progressHandler: progressHandler)
		}
	}
}
#endif
