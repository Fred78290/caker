import Foundation
import Virtualization
import GRPCLib

let cloudInitIso = "cloud-init.iso"

struct VMBuilder {
	private static func buildVM(vmName: String,
	                            vmLocation: VMLocation,
								autostart: Bool,
	                            displayRefit: Bool,
	                            cpu: UInt16?,
	                            memory: UInt64?,
	                            diskSizeGB: UInt16,
	                            userName: String,
	                            mainGroup: String,
	                            clearPassword: Bool,
	                            sshAuthorizedKey: String?,
	                            vendorData: String?,
	                            userData: String?,
	                            networkConfig: String?,
								forwardedPort: [ForwardedPort]) throws {
		// Create NVRAM
		_ = try VZEFIVariableStore(creatingVariableStoreAt: vmLocation.nvramURL)

		// Create disk
		try vmLocation.expandDiskTo(diskSizeGB)

		// Create config
		var config = CakeConfig(os: .linux, autostart: autostart, configuredUser: userName, displayRefit: displayRefit, cpuCountMin: 1, memorySizeMin: 512 * 1024 * 1024)
		let cloudInit = try CloudInit(userName: userName,
												 mainGroup: mainGroup,
												 clearPassword: clearPassword,
												 sshAuthorizedKeyPath: sshAuthorizedKey,
												 vendorDataPath: vendorData,
												 userDataPath: userData,
												 networkConfigPath: networkConfig)

		if let cpu = cpu {
			config.cpuCount = Int(cpu)
		}

		if let memory = memory {
			config.memorySize = memory * 1024 * 1024
		}

		try cloudInit.createDefaultCloudInit(name: vmName, cdromURL: URL(fileURLWithPath: cloudInitIso, relativeTo: vmLocation.diskURL))
		try config.save(to: vmLocation.rootURL)
	}

	@available(macOS 13, *)
	static func buildVM(vmName: String,
	                    vmLocation: VMLocation,
	                    cloudImageURL: URL,
						autostart: Bool,
	                    displayRefit: Bool,
	                    cpu: UInt16?,
	                    memory: UInt64?,
	                    diskSizeGB: UInt16,
	                    userName: String,
	                    mainGroup: String,
	                    clearPassword: Bool,
	                    sshAuthorizedKey: String?,
	                    vendorData: String?,
	                    userData: String?,
	                    networkConfig: String?,
						forwardedPort: [ForwardedPort]) async  throws {
		if cloudImageURL.isFileURL {
			try CloudImageConverter.convertCloudImageToRaw(from: cloudImageURL, to: vmLocation.diskURL)
		} else {
			try await CloudImageConverter.retrieveCloudImageAndConvert(from: cloudImageURL, to: vmLocation.diskURL)
		}

		try self.buildVM(vmName: vmName,
		                 vmLocation: vmLocation,
						 autostart: autostart,
		                 displayRefit: displayRefit,
		                 cpu: cpu,
		                 memory: memory,
		                 diskSizeGB: diskSizeGB,
		                 userName: userName,
		                 mainGroup: mainGroup,
		                 clearPassword: clearPassword,
		                 sshAuthorizedKey: sshAuthorizedKey,
		                 vendorData: vendorData,
		                 userData: userData,
		                 networkConfig: networkConfig,
						 forwardedPort: forwardedPort)
	}

	@available(macOS 13, *)
	static func buildVM(vmName: String,
	                    vmLocation: VMLocation,
	                    diskImageURL: URL,
						autostart: Bool,
	                    displayRefit: Bool,
	                    cpu: UInt16?,
	                    memory: UInt64?,
	                    diskSizeGB: UInt16,
	                    userName: String,
	                    mainGroup: String,
	                    clearPassword: Bool,
	                    sshAuthorizedKey: String?,
	                    vendorData: String?,
	                    userData: String?,
	                    networkConfig: String?,
						forwardedPort: [ForwardedPort]) async throws {
		var diskImageURL = diskImageURL

		if !diskImageURL.isFileURL {
			diskImageURL = try await CloudImageConverter.downloadLinuxImage(remoteURL: diskImageURL)
		}

		// Copy disk image
		diskImageURL.resolveSymlinksInPath()

		let temporaryDiskURL = try Home(asSystem: runAsSystem).temporaryDir.appendingPathComponent("tmp-disk-\(UUID().uuidString)")

		try FileManager.default.copyItem(at: diskImageURL, to: temporaryDiskURL)
		_ = try FileManager.default.replaceItemAt(vmLocation.diskURL, withItemAt: temporaryDiskURL)

		try self.buildVM(vmName: vmName,
		                 vmLocation: vmLocation,
						 autostart: autostart,
		                 displayRefit: displayRefit,
		                 cpu: cpu,
		                 memory: memory,
		                 diskSizeGB: diskSizeGB,
		                 userName: userName,
		                 mainGroup: mainGroup,
		                 clearPassword: clearPassword,
		                 sshAuthorizedKey: sshAuthorizedKey,
		                 vendorData: vendorData,
		                 userData: userData,
		                 networkConfig: networkConfig,
						 forwardedPort: forwardedPort)
	}

	@available(macOS 13, *)
	static func buildVM(vmName: String,
	                    vmLocation: VMLocation,
	                    ociImage: String,
						autostart: Bool,
	                    displayRefit: Bool,
	                    cpu: UInt16?,
	                    memory: UInt64?,
	                    diskSizeGB: UInt16,
	                    userName: String,
	                    mainGroup: String,
	                    clearPassword: Bool,
	                    sshAuthorizedKey: String?,
	                    vendorData: String?,
	                    userData: String?,
	                    networkConfig: String?,
						forwardedPort: [ForwardedPort]) async throws {

		try Shell.runTart(command: "clone", arguments: [ociImage, vmName, "--clearPassword"])

		let clonedLocation = try StorageLocation(asSystem: runAsSystem).find(vmName)

		_ = try FileManager.default.copyItem(at: clonedLocation.diskURL, to: vmLocation.diskURL)

		try FileManager.default.removeItem(at: clonedLocation.rootURL)

		try self.buildVM(vmName: vmName,
		                 vmLocation: vmLocation,
						 autostart: autostart,
		                 displayRefit: displayRefit,
		                 cpu: cpu,
		                 memory: memory,
		                 diskSizeGB: diskSizeGB,
		                 userName: userName,
		                 mainGroup: mainGroup,
		                 clearPassword: clearPassword,
		                 sshAuthorizedKey: sshAuthorizedKey,
		                 vendorData: vendorData,
		                 userData: userData,
		                 networkConfig: networkConfig,
						 forwardedPort: forwardedPort)
	}

	@available(macOS 13, *)
	static func buildVM(vmName: String,
	                    vmLocation: VMLocation,
	                    remoteContainerServer: String,
	                    aliasImage: String,
						autostart: Bool,
	                    displayRefit: Bool,
	                    cpu: UInt16?,
	                    memory: UInt64?,
	                    diskSizeGB: UInt16,
	                    userName: String,
	                    mainGroup: String,
	                    clearPassword: Bool,
	                    sshAuthorizedKey: String?,
	                    vendorData: String?,
	                    userData: String?,
	                    networkConfig: String?,
						forwardedPort: [ForwardedPort]) async throws {

		guard let remoteContainerServerURL = URL(string: remoteContainerServer) else {
			throw ServiceError("malformed url: \(remoteContainerServer)")
		}

		let simpleStream = try await SimpleStreamProtocol(baseURL: remoteContainerServerURL)
		let image: LinuxContainerImage = try await simpleStream.GetImageAlias(alias: aliasImage)

		try await image.retrieveSimpleStreamImageAndConvert(to: vmLocation.diskURL)

		try self.buildVM(vmName: vmName,
		                 vmLocation: vmLocation,
						 autostart: autostart,
		                 displayRefit: displayRefit,
		                 cpu: cpu,
		                 memory: memory,
		                 diskSizeGB: diskSizeGB,
		                 userName: userName,
		                 mainGroup: mainGroup,
		                 clearPassword: clearPassword,
		                 sshAuthorizedKey: sshAuthorizedKey,
		                 vendorData: vendorData,
		                 userData: userData,
		                 networkConfig: networkConfig,
						 forwardedPort: forwardedPort)
	}

	static func createCloudInitDrive(cdromURL: URL) throws -> VZStorageDeviceConfiguration {
		let attachment: VZDiskImageStorageDeviceAttachment = try VZDiskImageStorageDeviceAttachment(url: cdromURL,
		                                                                                            readOnly: true, cachingMode: .cached,
																									synchronizationMode: VZDiskImageSynchronizationMode.none)

		let cdrom = VZVirtioBlockDeviceConfiguration(attachment: attachment)

		cdrom.blockDeviceIdentifier = "CIDATA"

		return cdrom
	}

	static func adjustUrl(url: String) -> URL{
		if url.starts(with: "http://") || url.starts(with: "https://") || url.starts(with: "file://") {
			return URL(string: url)!
		} else {
			return URL(fileURLWithPath: NSString(string: url).expandingTildeInPath)
		}
	}

	public static func buildVM(vmName: String, vmLocation: VMLocation, arguments: BuildArguments) async throws {
		if let fromImage = arguments.fromImage {
			try await Self.buildVM(vmName: vmName,
			                       vmLocation: vmLocation,
			                       diskImageURL: adjustUrl(url: fromImage),
								   autostart: arguments.autostart,
			                       displayRefit: arguments.displayRefit,
			                       cpu: arguments.cpu,
			                       memory: arguments.memory,
			                       diskSizeGB: arguments.diskSize,
			                       userName: arguments.user,
			                       mainGroup: arguments.mainGroup,
			                       clearPassword: arguments.clearPassword,
			                       sshAuthorizedKey: arguments.sshAuthorizedKey,
			                       vendorData: arguments.vendorData,
			                       userData: arguments.userData,
			                       networkConfig: arguments.networkConfig,
								   forwardedPort: arguments.forwardedPort)
		} else if let cloudImage = arguments.cloudImage {
			try await Self.buildVM(vmName: vmName,
			                       vmLocation: vmLocation,
			                       cloudImageURL: adjustUrl(url: cloudImage),
								   autostart: arguments.autostart,
			                       displayRefit: arguments.displayRefit,
			                       cpu: arguments.cpu,
			                       memory: arguments.memory,
			                       diskSizeGB: arguments.diskSize,
			                       userName: arguments.user,
			                       mainGroup: arguments.mainGroup,
			                       clearPassword: arguments.clearPassword,
			                       sshAuthorizedKey: arguments.sshAuthorizedKey,
			                       vendorData: arguments.vendorData,
			                       userData: arguments.userData,
			                       networkConfig: arguments.networkConfig,
								   forwardedPort: arguments.forwardedPort)
		} else if let ociImage = arguments.ociImage {
			try await Self.buildVM(vmName: vmName,
			                       vmLocation: vmLocation,
			                       ociImage: ociImage,
								   autostart: arguments.autostart,
			                       displayRefit: arguments.displayRefit,
			                       cpu: arguments.cpu,
			                       memory: arguments.memory,
			                       diskSizeGB: arguments.diskSize,
			                       userName: arguments.user,
			                       mainGroup: arguments.mainGroup,
			                       clearPassword: arguments.clearPassword,
			                       sshAuthorizedKey: arguments.sshAuthorizedKey,
			                       vendorData: arguments.vendorData,
			                       userData: arguments.userData,
			                       networkConfig: arguments.networkConfig,
								   forwardedPort: arguments.forwardedPort)
		} else if let aliasImage = arguments.aliasImage {
			try await Self.buildVM(vmName: vmName,
			                       vmLocation: vmLocation,
			                       remoteContainerServer: arguments.remoteContainerServer,
			                       aliasImage: aliasImage,
								   autostart: arguments.autostart,
			                       displayRefit: arguments.displayRefit,
			                       cpu: arguments.cpu,
			                       memory: arguments.memory,
			                       diskSizeGB: arguments.diskSize,
			                       userName: arguments.user,
			                       mainGroup: arguments.mainGroup,
			                       clearPassword: arguments.clearPassword,
			                       sshAuthorizedKey: arguments.sshAuthorizedKey,
			                       vendorData: arguments.vendorData,
			                       userData: arguments.userData,
			                       networkConfig: arguments.networkConfig,
								   forwardedPort: arguments.forwardedPort)
		} else {
			throw ServiceError("any image specified")
		}

	}
}
