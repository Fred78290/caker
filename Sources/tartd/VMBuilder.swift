import Foundation
import ShellOut
import Virtualization

let cloudInitIso = "cloud-init.iso"

struct VMBuilder {
	private static func buildVM(vmName: String,
								vmDir: VMLocation,
								cpu: UInt16?,
								memory: UInt64?,
								diskSizeGB: UInt16,
								userName: String,
								mainGroup: String,
								insecure: Bool,
								sshAuthorizedKey: String?,
								vendorData: String?,
								userData: String?,
								networkConfig: String?) async throws {
		// Create NVRAM
		_ = try VZEFIVariableStore(creatingVariableStoreAt: vmDir.nvramURL)

		// Create disk
		try vmDir.expandDiskTo(diskSizeGB)

		// Create config
		var config = TartConfig(os: .linux, cpuCountMin: 1, memorySizeMin: 512 * 1024 * 1024)
		let cloudInit = try CloudInit(userName: userName,
									  mainGroup: mainGroup,
									  insecure: insecure,
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

		try cloudInit.createDefaultCloudInit(name: vmName, cdromURL: URL(fileURLWithPath: cloudInitIso, relativeTo: vmDir.diskURL))
		try config.save(toURL: vmDir.configURL)
	}

	@available(macOS 13, *)
	static func buildVM(vmName: String,
						vmDir: VMLocation,
						cloudImageURL: URL,
						cpu: UInt16?,
						memory: UInt64?,
						diskSizeGB: UInt16,
						userName: String,
						mainGroup: String,
						insecure: Bool,
						sshAuthorizedKey: String?,
						vendorData: String?,
						userData: String?,
						networkConfig: String?)async  throws {
		if cloudImageURL.isFileURL {
			try CloudImageConverter.convertCloudImageToRaw(from: cloudImageURL, to: vmDir.diskURL)
		} else {
			try await CloudImageConverter.retrieveCloudImageAndConvert(from: cloudImageURL, to: vmDir.diskURL)
		}

		try await self.buildVM(vmName: vmName,
							   vmDir: vmDir,
							   cpu: cpu,
							   memory: memory,
							   diskSizeGB: diskSizeGB,
							   userName: userName,
							   mainGroup: mainGroup,
							   insecure: insecure,
							   sshAuthorizedKey: sshAuthorizedKey,
							   vendorData: vendorData,
							   userData: userData,
							   networkConfig: networkConfig)
	}

	@available(macOS 13, *)
	static func buildVM(vmName: String,
						vmDir: VMLocation,
						diskImageURL: URL,
						cpu: UInt16?,
						memory: UInt64?,
						diskSizeGB: UInt16,
						userName: String,
						mainGroup: String,
						insecure: Bool,
						sshAuthorizedKey: String?,
						vendorData: String?,
						userData: String?,
						networkConfig: String?) async throws {
		var diskImageURL = diskImageURL

		if !diskImageURL.isFileURL {
			diskImageURL = try await CloudImageConverter.downloadLinuxImage(remoteURL: diskImageURL)
		}

		// Copy disk image
		diskImageURL.resolveSymlinksInPath()

		let temporaryDiskURL = try Home(asSystem: runAsSystem).temporaryDir.appendingPathComponent("tmp-disk-\(UUID().uuidString)")

		try FileManager.default.copyItem(at: diskImageURL, to: temporaryDiskURL)
		_ = try FileManager.default.replaceItemAt(vmDir.diskURL, withItemAt: temporaryDiskURL)

		try await self.buildVM(vmName: vmName,
							   vmDir: vmDir,
							   cpu: cpu,
							   memory: memory,
							   diskSizeGB: diskSizeGB,
							   userName: userName,
							   mainGroup: mainGroup,
							   insecure: insecure,
							   sshAuthorizedKey: sshAuthorizedKey,
							   vendorData: vendorData,
							   userData: userData,
							   networkConfig: networkConfig)
	}

	@available(macOS 13, *)
	static func buildVM(vmName: String,
						vmDir: VMLocation,
						ociImage: String,
						cpu: UInt16?,
						memory: UInt64?,
						diskSizeGB: UInt16,
						userName: String,
						mainGroup: String,
						insecure: Bool,
						sshAuthorizedKey: String?,
						vendorData: String?,
						userData: String?,
						networkConfig: String?) async throws {

		try Shell.runTart(command: "clone", arguments: [ociImage, vmName, "--insecure"])

		try await self.buildVM(vmName: vmName,
							   vmDir: vmDir,
							   cpu: cpu,
							   memory: memory,
							   diskSizeGB: diskSizeGB,
							   userName: userName,
							   mainGroup: mainGroup,
							   insecure: insecure,
							   sshAuthorizedKey: sshAuthorizedKey,
							   vendorData: vendorData,
							   userData: userData,
							   networkConfig: networkConfig)
	}

	@available(macOS 13, *)
	static func buildVM(vmName: String,
						vmDir: VMLocation,
						remoteContainerServer: String,
						aliasImage: String,
						cpu: UInt16?,
						memory: UInt64?,
						diskSizeGB: UInt16,
						userName: String,
						mainGroup: String,
						insecure: Bool,
						sshAuthorizedKey: String?,
						vendorData: String?,
						userData: String?,
						networkConfig: String?) async throws {

		guard let remoteContainerServerURL = URL(string: remoteContainerServer) else {
			throw ServiceError("malformed url: \(remoteContainerServer)")
		}

		let simpleStream = try await SimpleStreamProtocol(baseURL: remoteContainerServerURL)
		let image: LinuxContainerImage = try await simpleStream.GetImageAlias(alias: aliasImage)

		try await image.retrieveSimpleStreamImageAndConvert(to: vmDir.diskURL)

		try await self.buildVM(vmName: vmName,
							   vmDir: vmDir,
							   cpu: cpu,
							   memory: memory,
							   diskSizeGB: diskSizeGB,
							   userName: userName,
							   mainGroup: mainGroup,
							   insecure: insecure,
							   sshAuthorizedKey: sshAuthorizedKey,
							   vendorData: vendorData,
							   userData: userData,
							   networkConfig: networkConfig)
	}

	static func createCloudInitDrive(cdromURL: URL) throws -> VZStorageDeviceConfiguration {
		let attachment: VZDiskImageStorageDeviceAttachment = try VZDiskImageStorageDeviceAttachment(url: cdromURL,
																									readOnly: true, cachingMode: .cached, synchronizationMode: VZDiskImageSynchronizationMode.none)

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

	public static func buildVM(vmName: String, vmDir: VMLocation, arguments: BuildArguments) async throws {
		if let fromImage = arguments.fromImage {
			try await Self.buildVM(vmName: vmName,
								   vmDir: vmDir,
								   diskImageURL: adjustUrl(url: fromImage),
								   cpu: arguments.cpu,
								   memory: arguments.memory,
								   diskSizeGB: arguments.diskSize,
								   userName: arguments.user,
								   mainGroup: arguments.mainGroup,
								   insecure: arguments.insecure,
								   sshAuthorizedKey: arguments.sshAuthorizedKey,
								   vendorData: arguments.vendorData,
								   userData: arguments.userData,
								   networkConfig: arguments.networkConfig)
		} else if let cloudImage = arguments.cloudImage {
			try await Self.buildVM(vmName: vmName,
								   vmDir: vmDir,
								   cloudImageURL: adjustUrl(url: cloudImage),
								   cpu: arguments.cpu,
								   memory: arguments.memory,
								   diskSizeGB: arguments.diskSize,
								   userName: arguments.user,
								   mainGroup: arguments.mainGroup,
								   insecure: arguments.insecure,
								   sshAuthorizedKey: arguments.sshAuthorizedKey,
								   vendorData: arguments.vendorData,
								   userData: arguments.userData,
								   networkConfig: arguments.networkConfig)
		} else if let ociImage = arguments.ociImage {
			try await Self.buildVM(vmName: vmName,
								   vmDir: vmDir,
								   ociImage: ociImage,
								   cpu: arguments.cpu,
								   memory: arguments.memory,
								   diskSizeGB: arguments.diskSize,
								   userName: arguments.user,
								   mainGroup: arguments.mainGroup,
								   insecure: arguments.insecure,
								   sshAuthorizedKey: arguments.sshAuthorizedKey,
								   vendorData: arguments.vendorData,
								   userData: arguments.userData,
								   networkConfig: arguments.networkConfig)
		} else if let aliasImage = arguments.aliasImage {
			try await Self.buildVM(vmName: vmName,
								   vmDir: vmDir,
								   remoteContainerServer: arguments.remoteContainerServer,
								   aliasImage: aliasImage,
								   cpu: arguments.cpu,
								   memory: arguments.memory,
								   diskSizeGB: arguments.diskSize,
								   userName: arguments.user,
								   mainGroup: arguments.mainGroup,
								   insecure: arguments.insecure,
								   sshAuthorizedKey: arguments.sshAuthorizedKey,
								   vendorData: arguments.vendorData,
								   userData: arguments.userData,
								   networkConfig: arguments.networkConfig)
		} else {
			throw ServiceError("any image specified")
		}

	}
}
