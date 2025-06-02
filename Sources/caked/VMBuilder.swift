import Foundation
import GRPCLib
import Virtualization

let cloudInitIso = "cloud-init.iso"

struct VMBuilder {
	enum ImageSource: Int {
		case raw
		case cloud
		case oci
		case template
		case stream
	}

	private static func build(vmName: String, vmLocation: VMLocation, options: BuildOptions, source: ImageSource, runMode: Utils.RunMode) throws {
		let config: CakeConfig

		// Create config
		if source == .oci {
			config = try CakeConfig(location: vmLocation.rootURL, options: options)
		} else if try vmLocation.configURL.exists() {
			config = try vmLocation.config()

			config.macAddress = VZMACAddress.randomLocallyAdministered()

			if config.os == .darwin {
				config.ecid = VZMacMachineIdentifier()
			}
		} else {
			// Create NVRAM
			_ = try VZEFIVariableStore(creatingVariableStoreAt: vmLocation.nvramURL)
			config = CakeConfig(
				location: vmLocation.rootURL,
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
			config.attachedDisks = options.attachedDisks
		}

		// Create or resize disk
		if config.os == .darwin {
			try? vmLocation.expandDisk(options.diskSize)
		} else {
			try? vmLocation.resizeDisk(options.diskSize)
		}

		config.networks = options.networks
		config.mounts = options.mounts
		config.sockets = options.sockets
		config.console = options.consoleURL
		config.forwardedPorts = options.forwardedPorts
		config.dynamicPortFarwarding = options.dynamicPortForwarding
		config.suspendable = options.suspendable
		config.instanceID = "i-\(String(format: "%x", Int(Date().timeIntervalSince1970)))"

		try config.save()

		if config.os == .linux && config.useCloudInit {
			let cloudInit = try CloudInit(
				userName: options.user,
				password: options.password,
				mainGroup: options.mainGroup,
				clearPassword: options.clearPassword,
				sshAuthorizedKeyPath: options.sshAuthorizedKey,
				vendorDataPath: options.vendorData,
				userDataPath: options.userData,
				networkConfigPath: options.networkConfig,
				netIfnames: options.netIfnames,
				runMode: runMode)

			try cloudInit.createDefaultCloudInit(config: config, name: vmName, cdromURL: URL(fileURLWithPath: cloudInitIso, relativeTo: vmLocation.diskURL))
		}
	}

	public static func cloneImage(vmName: String, vmLocation: VMLocation, options: BuildOptions, runMode: Utils.RunMode) async throws -> ImageSource {
		if FileManager.default.fileExists(atPath: vmLocation.diskURL.path) {
			throw ServiceError("VM already exists")
		}
		var sourceImage: ImageSource = .cloud
		let remoteDb = try Home(runMode: runMode).remoteDatabase()
		var starter = ["http://", "https://", "cloud://", "file://", "oci://", "ocis://", "qcow2://", "img://", "template://"]
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

		guard let scheme = imageURL.scheme else {
			throw ServiceError("unsupported image url: \(options.image)")
		}

		if imageURL.isFileURL || scheme == "img" {
			imageURL.resolveSymlinksInPath()

			let temporaryDiskURL: URL = try Home(runMode: runMode).temporaryDirectory.appendingPathComponent("tmp-disk-\(UUID().uuidString)")

			try FileManager.default.copyItem(at: imageURL, to: temporaryDiskURL)
			_ = try FileManager.default.replaceItemAt(vmLocation.diskURL, withItemAt: temporaryDiskURL)
			try? FileManager.default.removeItem(at: temporaryDiskURL)

			sourceImage = .raw
		} else if scheme == "template" {
			let templateName = imageURL.host()!
			let templateLocation = try StorageLocation(runMode: runMode, template: true).find(templateName)

			try templateLocation.copyTo(vmLocation)
			sourceImage = .template
		} else if scheme == "qcow2" {
			try CloudImageConverter.convertCloudImageToRaw(from: imageURL, to: vmLocation.diskURL)
		} else if scheme == "http" || scheme == "https" {
			try await CloudImageConverter.retrieveCloudImageAndConvert(from: imageURL, to: vmLocation.diskURL, runMode: runMode)
		} else if scheme == "cloud" {
			try await CloudImageConverter.retrieveCloudImageAndConvert(from: URL(string: imageURL.absoluteString.replacingOccurrences(of: "cloud://", with: "https://"))!, to: vmLocation.diskURL, runMode: runMode)
		} else if scheme == "oci" || scheme == "ocis" {
			if Root.tartIsPresent == false {
				throw ServiceError("tart is not installed")
			}

			let ociImage = options.image.stringAfter(after: "//")
			let arguments: [String]

			if scheme == "oci" {
				arguments = [ociImage, vmName, "--insecure"]
			} else {
				arguments = [ociImage, vmName]
			}

			try Shell.runTart(command: "clone", arguments: arguments, runMode: runMode)

			sourceImage = .oci
		} else if let remoteContainerServer = remoteDb.get(scheme), let aliasImage = options.image.split(separator: try Regex("[:/]"), maxSplits: 1, omittingEmptySubsequences: true).last {
			guard let remoteContainerServerURL: URL = URL(string: remoteContainerServer) else {
				throw ServiceError("malformed url: \(remoteContainerServer)")
			}

			let simpleStream = try await SimpleStreamProtocol(baseURL: remoteContainerServerURL, runMode: runMode)
			let image: LinuxContainerImage = try await simpleStream.GetImageAlias(alias: String(aliasImage), runMode: runMode)

			try await image.retrieveSimpleStreamImageAndConvert(to: vmLocation.diskURL, runMode: runMode)

			sourceImage = .stream
		} else {
			throw ServiceError("unsupported image url: \(options.image)")
		}

		return sourceImage
	}

	public static func buildVM(vmName: String, vmLocation: VMLocation, options: BuildOptions, runMode: Utils.RunMode) async throws -> ImageSource {
		let sourceImage = try await self.cloneImage(vmName: vmName, vmLocation: vmLocation, options: options, runMode: runMode)

		if sourceImage == .oci {
			let vmLocation = try StorageLocation(runMode: runMode).find(vmName)

			do {
				try self.build(vmName: vmName, vmLocation: vmLocation, options: options, source: sourceImage, runMode: runMode)
			} catch {
				try? vmLocation.delete()
				throw error
			}
		} else {
			try self.build(vmName: vmName, vmLocation: vmLocation, options: options, source: sourceImage, runMode: runMode)
		}

		return sourceImage
	}
}
