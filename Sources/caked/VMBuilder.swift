import Foundation
import Virtualization
import GRPCLib

let cloudInitIso = "cloud-init.iso"

struct VMBuilder {
	private static func build(vmName: String, vmLocation: VMLocation, options: BuildOptions) throws {
		// Create NVRAM
		_ = try VZEFIVariableStore(creatingVariableStoreAt: vmLocation.nvramURL)

		// Create disk
		try vmLocation.expandDiskTo(options.diskSize)

		// Create config
		var config = CakeConfig(os: .linux,
			autostart: options.autostart,
			configuredUser: options.user,
			displayRefit: options.displayRefit,
			cpuCountMin: 1,
			memorySizeMin: 512 * 1024 * 1024)

		config.cpuCount = Int(options.cpu)
		config.memorySize = options.memory * 1024 * 1024
		config.nested = options.nested
		config.displayRefit = options.displayRefit
		config.autostart = options.autostart
		config.netBridged = options.netBridged
//		config.netSoftnet = options.netSoftnet
//		config.netSoftnetAllow = options.netSoftnetAllow
//		config.netHost = options.netHost
		config.mounts = options.mounts
		config.forwardedPort = options.forwardedPort

		try config.save(to: vmLocation.configURL)

		let cloudInit = try CloudInit(userName: options.user,
									  password: options.password,
									  mainGroup: options.mainGroup,
									  clearPassword: options.clearPassword,
									  sshAuthorizedKeyPath: options.sshAuthorizedKey,
									  vendorDataPath: options.vendorData,
									  userDataPath: options.userData,
									  networkConfigPath: options.networkConfig)

		try cloudInit.createDefaultCloudInit(name: vmName, cdromURL: URL(fileURLWithPath: cloudInitIso, relativeTo: vmLocation.diskURL))
	}

	public static func buildVM(vmName: String, vmLocation: VMLocation, options: BuildOptions) async throws {
		let remoteDb = try Home(asSystem: runAsSystem).remoteDatabase()
		var starter = ["http://", "https://", "file://", "oci://", "ocis://", "qcow2://"]
		let remotes = remoteDb.keys
		var imageURL: URL

		starter.append(contentsOf: remotes)

		if starter.first(where: { start in return options.image.starts(with: start) }) != nil {
			imageURL = URL(string: options.image)!
		} else if options.image.contains(":") == false {
			imageURL = URL(fileURLWithPath: NSString(string: options.image).expandingTildeInPath)
		} else {
			throw ServiceError("unsupported url: \(options.image)")
		}

		if imageURL.isFileURL {
			imageURL.resolveSymlinksInPath()

			let temporaryDiskURL: URL = try Home(asSystem: runAsSystem).temporaryDir.appendingPathComponent("tmp-disk-\(UUID().uuidString)")

			try FileManager.default.copyItem(at: imageURL, to: temporaryDiskURL)
			_ = try FileManager.default.replaceItemAt(vmLocation.diskURL, withItemAt: temporaryDiskURL)
		} else if imageURL.scheme == "qcow2" {
			try CloudImageConverter.convertCloudImageToRaw(from: imageURL, to: vmLocation.diskURL)
		} else if imageURL.scheme == "http" || imageURL.scheme == "https" {
			try await CloudImageConverter.retrieveCloudImageAndConvert(from: imageURL, to: vmLocation.diskURL)
		} else if imageURL.scheme == "oci" || imageURL.scheme == "ocis" {
			let ociImage = options.image.stringAfter(after: "//")
			let arguments: [String]

			if imageURL.scheme == "oci" {
				arguments = [ociImage, vmName, "--insecure"]
			} else {
				arguments = [ociImage, vmName]
			}

			try Shell.runTart(command: "clone", arguments: arguments)

			let clonedLocation = try StorageLocation(asSystem: runAsSystem).find(vmName)

			_ = try FileManager.default.copyItem(at: clonedLocation.diskURL, to: vmLocation.diskURL)

			try FileManager.default.removeItem(at: clonedLocation.rootURL)
		} else if let remote = remotes.first(where: { start in return options.image.starts(with: start) }) {
			let aliasImage: Dictionary<String, String>.Keys.Element = options.image.stringAfter(after: remote+":")
			let remoteContainerServer = remoteDb.get(remote)!

			guard let remoteContainerServerURL: URL = URL(string: remoteContainerServer) else {
				throw ServiceError("malformed url: \(remoteContainerServer)")
			}

			let simpleStream = try await SimpleStreamProtocol(baseURL: remoteContainerServerURL)
			let image: LinuxContainerImage = try await simpleStream.GetImageAlias(alias: aliasImage)

			try await image.retrieveSimpleStreamImageAndConvert(to: vmLocation.diskURL)
		} else {
			throw ServiceError("unsupported image url: \(options.image)")
		}

		try self.build(vmName: vmName, vmLocation: vmLocation, options: options)
	}
}
