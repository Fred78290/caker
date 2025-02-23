import Foundation
import Virtualization
import GRPCLib

let cloudInitIso = "cloud-init.iso"

struct VMBuilder {
	enum ImageSource: Int {
		case raw
		case cloud
		case oci
		case template
		case stream
	}

	private static func build(vmName: String, vmLocation: VMLocation, options: BuildOptions, source: ImageSource) throws {
		let config: CakeConfig

		// Create or resize disk
		try? vmLocation.expandDiskTo(options.diskSize)

		// Create config
		if source == .oci {
			config = try CakeConfig(location: vmLocation.rootURL, options: options)
		} else {
			// Create NVRAM
			_ = try VZEFIVariableStore(creatingVariableStoreAt: vmLocation.nvramURL)
			config = CakeConfig(location: vmLocation.rootURL,
				os: .linux,
				autostart: options.autostart,
				configuredUser: options.user,
				configuredPassword: options.password,
				displayRefit: options.displayRefit,
				cpuCountMin: Int(options.cpu),
				memorySizeMin: options.memory * 1024 * 1024)

			config.useCloudInit = true
			config.agent = true
			config.nested = options.nested
		}

		config.networks = options.networks
		config.mounts = options.mounts
		config.sockets = options.sockets
		config.console = options.consoleURL
		config.forwardedPorts = options.forwardedPorts

		try config.save()

		if config.os == .linux && config.useCloudInit {
			let cloudInit = try CloudInit(userName: options.user,
										password: options.password,
										mainGroup: options.mainGroup,
										clearPassword: options.clearPassword,
										sshAuthorizedKeyPath: options.sshAuthorizedKey,
										vendorDataPath: options.vendorData,
										userDataPath: options.userData,
										networkConfigPath: options.networkConfig)

			try cloudInit.createDefaultCloudInit(config: config, name: vmName, cdromURL: URL(fileURLWithPath: cloudInitIso, relativeTo: vmLocation.diskURL))
		}
	}

	public static func cloneImage(vmName: String, vmLocation: VMLocation, options: BuildOptions) async throws -> ImageSource {
		if FileManager.default.fileExists(atPath: vmLocation.diskURL.path()) {
			throw ServiceError("VM already exists")
		}
		var sourceImage: ImageSource = .cloud
		let remoteDb = try Home(asSystem: runAsSystem).remoteDatabase()
		var starter = ["http://", "https://", "file://", "oci://", "ocis://", "qcow2://", "img://", "template://"]
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

		if imageURL.isFileURL || imageURL.scheme == "img" {
			imageURL.resolveSymlinksInPath()

			let temporaryDiskURL: URL = try Home(asSystem: runAsSystem).temporaryDir.appendingPathComponent("tmp-disk-\(UUID().uuidString)")

			try FileManager.default.copyItem(at: imageURL, to: temporaryDiskURL)
			_ = try FileManager.default.replaceItemAt(vmLocation.diskURL, withItemAt: temporaryDiskURL)
			try? FileManager.default.removeItem(at: temporaryDiskURL)

			sourceImage = .raw
		} else if imageURL.scheme == "template" {
			let templateName = imageURL.host()!
			let templateLocation = try StorageLocation(asSystem: runAsSystem, template: true).find(templateName)

			try FileManager.default.copyItem(at: templateLocation.diskURL, to: vmLocation.diskURL)
			sourceImage = .template
		} else if imageURL.scheme == "qcow2" {
			try CloudImageConverter.convertCloudImageToRaw(from: imageURL, to: vmLocation.diskURL)
		} else if imageURL.scheme == "http" || imageURL.scheme == "https" {
			try await CloudImageConverter.retrieveCloudImageAndConvert(from: imageURL, to: vmLocation.diskURL)
		} else if imageURL.scheme == "oci" || imageURL.scheme == "ocis" {
			if Root.tartIsPresent == false {
				throw ServiceError("tart is not installed")
			}

			let ociImage = options.image.stringAfter(after: "//")
			let arguments: [String]

			if imageURL.scheme == "oci" {
				arguments = [ociImage, vmName, "--insecure"]
			} else {
				arguments = [ociImage, vmName]
			}

			try Shell.runTart(command: "clone", arguments: arguments)

			sourceImage = .oci
		} else if let remote = remotes.first(where: { start in return options.image.starts(with: start) }) {
			let aliasImage: Dictionary<String, String>.Keys.Element = options.image.stringAfter(after: remote+":")
			let remoteContainerServer = remoteDb.get(remote)!

			guard let remoteContainerServerURL: URL = URL(string: remoteContainerServer) else {
				throw ServiceError("malformed url: \(remoteContainerServer)")
			}

			let simpleStream = try await SimpleStreamProtocol(baseURL: remoteContainerServerURL)
			let image: LinuxContainerImage = try await simpleStream.GetImageAlias(alias: aliasImage)

			try await image.retrieveSimpleStreamImageAndConvert(to: vmLocation.diskURL)

			sourceImage = .stream
		} else {
			throw ServiceError("unsupported image url: \(options.image)")
		}

		return sourceImage
	}

	public static func buildVM(vmName: String, vmLocation: VMLocation, options: BuildOptions) async throws -> ImageSource {
		let sourceImage = try await self.cloneImage(vmName: vmName, vmLocation: vmLocation, options: options)

		if sourceImage == .oci {
			let vmLocation = try StorageLocation(asSystem: runAsSystem).find(vmName)

			do {
				try self.build(vmName: vmName, vmLocation: vmLocation, options: options, source: sourceImage)
			} catch {
				try? vmLocation.delete()
				throw error
			}
		} else {
			try self.build(vmName: vmName, vmLocation: vmLocation, options: options, source: sourceImage)
		}

		return sourceImage
	}
}
