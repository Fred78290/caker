import Foundation
import GRPCLib
import Virtualization

let cloudInitIso = "cloud-init.iso"

#if arch(arm64)
	let knownSchemes = ["http://", "https://", "cloud://", "file://", "oci://", "ocis://", "qcow2://", "img://", "template://", "iso://", "ipsw://"]
#else
	let knownSchemes = ["http://", "https://", "cloud://", "file://", "oci://", "ocis://", "qcow2://", "img://", "template://", "iso://"]
#endif

public struct VMBuilder {
	public static let memoryMinSize: UInt64 = 512 * 1024 * 1024

	public enum ImageSource: Int, Hashable, CaseIterable, CustomStringConvertible, Sendable {
		public var description: String {
			switch self {
			case .raw: return "local"
			case .cloud: return "cloud"
			case .oci: return "oci"
			case .template: return "template"
			case .stream: return "stream"
			case .iso: return "iso"
			#if arch(arm64)
				case .ipsw: return "ipsw"
			#endif
			}
		}

		case raw
		case cloud
		case oci
		case template
		case stream
		case iso
		#if arch(arm64)
			case ipsw
		#endif

		public init(stringValue: String) {
			switch stringValue.lowercased() {
			case "iso": self = .iso
			case "raw": self = .raw
			case "cloud": self = .cloud
			case "oci": self = .oci
			case "template": self = .template
			case "stream": self = .stream
			#if arch(arm64)
				case "ipsw": self = .ipsw
			#endif
			default:
				self = .iso
			}
		}

		static var allCases: [String] {
			#if arch(arm64)
				["iso", "ipsw", "raw", "cloud", "oci", "template", "stream"]
			#else
				["iso", "raw", "cloud", "oci", "template", "stream"]
			#endif
		}

		public var supportCloudInit: Bool {
			#if arch(arm64)
				if self == .ipsw || self == .iso {
					return false
				}
			#else
				if self == .iso {
					return false
				}
			#endif

			return true
		}
	}

	#if arch(arm64)
		private static func installIPSW(location: VMLocation, config: CakeConfig, ipsw: URL, runMode: Utils.RunMode, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
			let vm = try IPSWInstaller(location: location, config: config, runMode: runMode, queue: queue)

			try await vm.installIPSW(ipsw, progressHandler: progressHandler)
		}
	#endif

	private static func build(vmName: String, location: VMLocation, options: BuildOptions, source: ImageSource, runMode: Utils.RunMode, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
		var config: CakeConfig! = nil
		var attachedDisks = options.attachedDisks

		// Create config
		#if arch(arm64)
			let imageURL = URL(fileURLWithPath: options.image.expandingTildeInPath.stringAfter(after: "ipsw://"))

			if source == .ipsw {
				let image = try await withCheckedThrowingContinuation { continuation in
					VZMacOSRestoreImage.load(from: imageURL) { result in
						continuation.resume(with: result)
					}
				}

				guard let requirements = image.mostFeaturefulSupportedConfiguration else {
					throw ServiceError("Unsupported restore image")
				}

				_ = try VZMacAuxiliaryStorage(creatingStorageAt: location.nvramURL, hardwareModel: requirements.hardwareModel)

				config = CakeConfig(
					location: location.rootURL,
					os: .darwin,
					autostart: options.autostart,
					configuredUser: options.user,
					configuredPassword: options.password,
					configuredGroup: options.mainGroup,
					configuredPlatform: .unknown,
					displayRefit: options.displayRefit,
					ifname: options.netIfnames,
					cpuCountMin: max(requirements.minimumSupportedCPUCount, Int(options.cpu)),
					memorySize: max(requirements.minimumSupportedMemorySize, options.memory * 1024 * 1024),
					memorySizeMin: requirements.minimumSupportedMemorySize,
					screenSize: options.screenSize
				)

				config.hardwareModel = requirements.hardwareModel
				config.ecid = VZMacMachineIdentifier()
				config.useCloudInit = false
				config.agent = false
				config.nested = options.nested
				config.attachedDisks = attachedDisks
			}
		#endif

		if config == nil {
			if source == .oci {
				config = try CakeConfig(location: location.rootURL, options: options)
			} else if try location.configURL.exists() {
				config = try location.config()

				config.macAddress = VZMACAddress.randomLocallyAdministered()

				if config.os == .darwin {
					#if arch(arm64)
						config.ecid = VZMacMachineIdentifier()
					#else
						throw ServiceError("macOS VMs are only supported on Apple Silicon Macs")
					#endif
				}
			} else {
				// Create NVRAM
				_ = try VZEFIVariableStore(creatingVariableStoreAt: location.nvramURL)

				if source == .iso {
					attachedDisks.append(DiskAttachement(diskPath: URL(string: options.image)!))
				}

				config = CakeConfig(
					location: location.rootURL,
					os: .linux,
					autostart: options.autostart,
					configuredUser: options.user,
					configuredPassword: options.password,
					configuredGroup: options.mainGroup,
					configuredPlatform: SupportedPlatform(rawValue: options.image),
					displayRefit: options.displayRefit,
					ifname: options.netIfnames,
					cpuCountMin: Int(options.cpu),
					memorySize: options.memory * 1024 * 1024,
					memorySizeMin: Self.memoryMinSize,
					screenSize: options.screenSize)

				config.useCloudInit = source != .iso || options.autoinstall
				config.agent = source != .iso || options.autoinstall
				config.nested = options.nested
				config.attachedDisks = attachedDisks
			}
		}

		if let config = config {
			// Create or resize disk
			if config.os == .darwin {
				try? location.expandDisk(options.diskSize)
			} else {
				try? location.resizeDisk(options.diskSize)
			}

			config.networks = options.networks
			config.mounts = options.mounts
			config.sockets = options.sockets
			config.console = options.consoleURL
			config.forwardedPorts = options.forwardedPorts
			config.dynamicPortForwarding = options.dynamicPortForwarding
			config.suspendable = options.suspendable
			config.instanceID = "i-\(String(format: "%x", Int(Date().timeIntervalSince1970)))"
			config.source = source

			try config.save()

			if config.os == .linux && config.useCloudInit {
				let cloudInit = try CloudInit(
					plateform: SupportedPlatform(rawValue: options.image),
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

				try cloudInit.createDefaultCloudInit(config: config, name: vmName, cdromURL: URL(fileURLWithPath: cloudInitIso, relativeTo: location.diskURL))
			}

			#if arch(arm64)
				if source == .ipsw {
					try await installIPSW(location: location, config: config, ipsw: imageURL, runMode: runMode, queue: queue, progressHandler: progressHandler)
				}
			#endif
		}
	}

	public static func cloneImage(vmName: String, location: VMLocation, options: BuildOptions, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws -> ImageSource {
		if FileManager.default.fileExists(atPath: location.diskURL.path) {
			throw ServiceError("VM already exists")
		}
		var sourceImage: ImageSource = .cloud
		let remoteDb = try Home(runMode: runMode).remoteDatabase()
		var starter: [String] = []
		let remotes = remoteDb.keys
		var imageURL: URL

		func aliasImage(_ image: String) -> String {
			if image.contains(":///") {
				return image.stringAfter(after: ":///")
			} else if image.contains("://") {
				return image.stringAfter(after: "://")
			} else if image.contains(":/") {
				return image.stringAfter(after: ":/")
			} else {
				return image.stringAfter(after: ":")
			}
		}

		starter.append(contentsOf: knownSchemes)
		starter.append(contentsOf: remotes)

		if starter.first(where: { start in return options.image.starts(with: start) }) != nil {
			imageURL = URL(string: options.image)!
		} else if options.image.contains(":") == false {
			imageURL = URL(fileURLWithPath: options.image.expandingTildeInPath)
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
			_ = try FileManager.default.replaceItemAt(location.diskURL, withItemAt: temporaryDiskURL)
			try? FileManager.default.removeItem(at: temporaryDiskURL)

			sourceImage = .raw
		} else if scheme == "template" {
			let templateName = imageURL.host()!
			let templateLocation = try StorageLocation(runMode: runMode, template: true).find(templateName)

			try templateLocation.copyTo(location)
			sourceImage = .template
		} else if scheme == "qcow2" {
			try CloudImageConverter.convertCloudImageToRaw(from: imageURL, to: location.diskURL, progressHandler: progressHandler)
		} else if scheme == "http" || scheme == "https" {
			try await CloudImageConverter.retrieveCloudImageAndConvert(from: imageURL, to: location.diskURL, runMode: runMode, progressHandler: progressHandler)
		} else if scheme == "cloud" {
			try await CloudImageConverter.retrieveCloudImageAndConvert(from: URL(string: imageURL.absoluteString.replacingOccurrences(of: "cloud://", with: "https://"))!, to: location.diskURL, runMode: runMode, progressHandler: progressHandler)
		} else if scheme == "oci" || scheme == "ocis" {
			let ociImage = options.image.stringAfter(after: "//")
			let pulled = try await PullHandler.pull(location: location, image: ociImage, insecure: scheme == "oci", runMode: runMode, progressHandler: progressHandler)

			if pulled.success == false {
				throw ServiceError(pulled.message)
			}

			sourceImage = .oci
		} else if scheme == "iso" {
			sourceImage = .iso
		} else if scheme == "ipsw" {
			#if arch(arm64)
				sourceImage = .ipsw
			#else
				throw ServiceError("unsupported image url: \(options.image)")
			#endif
		} else if let remoteContainerServer = remoteDb.get(scheme) {
			guard let remoteContainerServerURL: URL = URL(string: remoteContainerServer) else {
				throw ServiceError("malformed url: \(remoteContainerServer)")
			}

			let aliasImage = aliasImage(options.image)
			let simpleStream = try await SimpleStreamProtocol(baseURL: remoteContainerServerURL, runMode: runMode)
			let image: LinuxContainerImage = try await simpleStream.GetImageAlias(alias: String(aliasImage), runMode: runMode)

			try await image.retrieveSimpleStreamImageAndConvert(to: location.diskURL, runMode: runMode, progressHandler: progressHandler)

			sourceImage = .stream
		} else {
			throw ServiceError("unsupported image url: \(options.image)")
		}

		return sourceImage
	}

	static func buildVM(vmName: String, location: VMLocation, options: BuildOptions, runMode: Utils.RunMode, queue: DispatchQueue?, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws -> ImageSource {
		let sourceImage = try await self.cloneImage(vmName: vmName, location: location, options: options, runMode: runMode, progressHandler: progressHandler)

		try await self.build(vmName: vmName, location: location, options: options, source: sourceImage, runMode: runMode, queue: queue, progressHandler: progressHandler)

		return sourceImage
	}
}
