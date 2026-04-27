import Foundation
import GRPCLib
import Virtualization
import SwiftUI

let cloudInitIso = "cloud-init.iso"

public struct VMBuilder {
	public static let memoryMinSize: UInt64 = 512 * MoB

	#if arch(arm64)
		private static func installIPSW(location: VMLocation, config: CakeConfig, ipsw: URL, runMode: Utils.RunMode, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
			let vm = try IPSWInstaller(location: location, config: config, runMode: runMode, queue: queue)

			try await vm.installIPSW(ipsw, progressHandler: progressHandler)
		}
	#endif

	private static func build(vmName: String, location: VMLocation, options: BuildOptions, runMode: Utils.RunMode, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
		let imageSource = options.imageSource!
		let imageURL = URL(string: options.image)!
		var config: CakeConfig! = nil
		var attachedDisks = options.attachedDisks

		// Create config
		#if arch(arm64)
			if imageSource == .ipsw {
				let image = try await withCheckedThrowingContinuation { continuation in
					VZMacOSRestoreImage.load(from: imageURL) { result in
						continuation.resume(with: result)
					}
				}

				guard let requirements = image.mostFeaturefulSupportedConfiguration else {
					throw ServiceError(String(localized: "Unsupported restore image"))
				}

				_ = try VZMacAuxiliaryStorage(creatingStorageAt: location.nvramURL, hardwareModel: requirements.hardwareModel)

				config = CakeConfig(
					location: location.rootURL,
					os: .darwin,
					autostart: options.autostart,
					configuredUser: options.user,
					configuredPassword: options.password,
					configuredGroup: options.mainGroup,
					configuredGroups: options.otherGroup,
					configuredPlatform: .unknown,
					clearPassword: options.clearPassword,
					displayRefit: options.displayRefit,
					ifname: options.netIfnames,
					cpuCountMin: max(UInt16(requirements.minimumSupportedCPUCount), options.cpu),
					memorySize: max(requirements.minimumSupportedMemorySize, options.memory * MoB),
					memorySizeMin: requirements.minimumSupportedMemorySize,
					screenSize: options.screenSize
				)

				config.hardwareModel = requirements.hardwareModel.dataRepresentation
				config.ecid = VZMacMachineIdentifier().dataRepresentation
				config.useCloudInit = false
				config.agent = false
				config.nested = options.nested
				config.attachedDisks = attachedDisks
			}
		#endif

		if config == nil {
			if imageSource == .oci {
				config = try CakeConfig(location: location.rootURL, options: options)
			} else if try location.configURL.exists() {
				config = try location.config()

				config.macAddress = VZMACAddress.randomLocallyAdministered().string

				if config.os == .darwin {
					#if arch(arm64)
						config.ecid = VZMacMachineIdentifier().dataRepresentation
					#else
						throw ServiceError(String(localized: "macOS VMs are only supported on Apple Silicon Macs"))
					#endif
				}
			} else {
				// Create NVRAM
				_ = try VZEFIVariableStore(creatingVariableStoreAt: location.nvramURL)

				if imageSource == .iso {
					attachedDisks.append(DiskAttachement(diskPath: URL(string: options.image)!))
				}

				config = CakeConfig(
					location: location.rootURL,
					os: .linux,
					autostart: options.autostart,
					configuredUser: options.user,
					configuredPassword: options.password,
					configuredGroup: options.mainGroup,
					configuredGroups: options.otherGroup,
					configuredPlatform: SupportedPlatform(rawValue: options.image),
					clearPassword: options.clearPassword,
					displayRefit: options.displayRefit,
					ifname: options.netIfnames,
					cpuCountMin: options.cpu,
					memorySize: options.memory * MoB,
					memorySizeMin: Self.memoryMinSize,
					screenSize: options.screenSize)

				config.useCloudInit = imageSource != .iso || options.autoinstall
				config.agent = imageSource != .iso || options.autoinstall
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

			config.networks = options.allNetworks
			config.mounts = options.mounts
			config.sockets = options.sockets
			config.console = options.consoleURL?.description
			config.forwardedPorts = options.forwardedPorts
			config.dynamicPortForwarding = options.dynamicPortForwarding
			config.suspendable = options.suspendable
			config.instanceID = "i-\(String(format: "%x", Int(Date().timeIntervalSince1970)))"
			config.source = imageSource

			try config.save()

			if config.os == .linux && config.useCloudInit {
				let cloudInit = try CloudInit(
					plateform: SupportedPlatform(rawValue: options.image),
					userName: options.user,
					password: options.password,
					mainGroup: options.mainGroup,
					otherGroups: options.otherGroup,
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
				if imageSource == .ipsw {
					try await installIPSW(location: location, config: config, ipsw: imageURL, runMode: runMode, queue: queue, progressHandler: progressHandler)
				}
			#endif
		}
	}

	public static func cloneImage(vmName: String, location: VMLocation, options: BuildOptions, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws -> BuildOptions {
		if FileManager.default.fileExists(atPath: location.diskURL.path) {
			throw ServiceError(String(localized: "VM already exists"))
		}
		var options = options
		var sourceImage = options.imageSource
		let remoteDb = try Home(runMode: runMode).remoteDatabase()
		let remotes = remoteDb.keys.map { $0 }

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

		guard var imageURL = URL(string: options.image) else {
			throw ServiceError(String(localized: "unsupported url: \(options.image)"))
		}

		if sourceImage == nil {
			var scheme: String

			if let s = imageURL.scheme {
				scheme = s

				if s == "http" && imageURL.pathExtension == "iso" {
					scheme = "iso"
				} else if s == "https" && imageURL.pathExtension == "iso" {
					scheme = "isos"
				} else if imageURL.pathExtension == "ipsw" {
					scheme = "ipsw"
				}
			} else {
				scheme = imageURL.pathExtension
			}

			if let imageSource = ImageSource.schemes[scheme] {
				sourceImage = imageSource
				if imageURL.host == nil {
					imageURL = URL(fileURLWithPath: imageURL.path.expandingTildeInPath)
				} else if var components = URLComponents(url: imageURL, resolvingAgainstBaseURL: false) {
					switch scheme {
						case "qcow2", "imgs", "isos", "ipsw", "https", "ocis":
						components.scheme = "https"
						default:
						components.scheme = "http"
					}

					imageURL = components.url!
				}
			} else if remotes.contains(scheme) {
				imageURL = URL(string: options.image)!
				sourceImage = .stream
			} else {
				throw ServiceError(String(localized: "unsupported url: \(options.image)"))
			}

			options.imageSource = sourceImage
		} else {
			imageURL = URL(string: options.image)!
		}

		let imageIsFile = imageURL.isFileURL || imageURL.host == nil

		if sourceImage == .raw {
			let temporaryDiskURL: URL = try Home(runMode: runMode).temporaryDirectory.appendingPathComponent("tmp-disk-\(UUID().uuidString)")

			if imageIsFile {
				imageURL.resolveSymlinksInPath()
				try FileManager.default.copyItem(at: imageURL, to: temporaryDiskURL)
			} else {
				imageURL = try await CloudImageConverter.downloadRemoteFile(fromURL: imageURL, toURL: temporaryDiskURL, runMode: runMode, progressHandler: progressHandler)
			}

			_ = try FileManager.default.replaceItemAt(location.diskURL, withItemAt: temporaryDiskURL)
			try? FileManager.default.removeItem(at: temporaryDiskURL)
		} else if sourceImage == .template {
			guard let templateName = imageURL.host else {
				throw ServiceError(String(localized: "Wrong URL for template"))
			}

			let templateLocation = try StorageLocation(runMode: runMode, template: true).find(templateName)

			try templateLocation.copyTo(location)
		} else if sourceImage == .qcow2 {
			if imageIsFile {
				try CloudImageConverter.convertCloudImageToRaw(from: imageURL, to: location.diskURL, progressHandler: progressHandler)
			} else {
				try await CloudImageConverter.retrieveCloudImageAndConvert(from: imageURL, to: location.diskURL, runMode: runMode, progressHandler: progressHandler)
			}
		} else if sourceImage == .oci {
			let ociImage = options.image.stringAfter(after: "//")
			let pulled = try await PullHandler.pull(location: location, image: ociImage, insecure: ["http", "oci"].contains(imageURL.scheme), runMode: runMode, progressHandler: progressHandler)

			if pulled.success == false {
				throw ServiceError(pulled.message)
			}
		} else if sourceImage == .iso {
			if imageIsFile == false {
				options.image = try await CloudImageConverter.downloadISO(remoteURL: imageURL, runMode: runMode, progressHandler: progressHandler).absoluteString
			}

		} else if sourceImage == .ipsw {
			#if arch(arm64)
			if imageIsFile == false {
				options.image = try await CloudImageConverter.downloadIPSW(remoteURL: imageURL, runMode: runMode, progressHandler: progressHandler).absoluteString
			}
			#else
				throw ServiceError(String(localized: "IPSW is only available on arm64 architecture: \(options.image)"))
			#endif
		} else if sourceImage == .stream {
			let scheme = imageURL.scheme!

			guard let remoteContainerServer = remoteDb.get(scheme) else {
				throw ServiceError(String(localized: "remote stream \(scheme) not found"))
			}

			guard let remoteContainerServerURL: URL = URL(string: remoteContainerServer) else {
				throw ServiceError(String(localized: "malformed url: \(remoteContainerServer)"))
			}

			let aliasImage = aliasImage(options.image)
			let simpleStream = try await SimpleStreamProtocol(baseURL: remoteContainerServerURL, runMode: runMode)
			let image: LinuxContainerImage = try await simpleStream.GetImageAlias(alias: String(aliasImage), runMode: runMode)

			try await image.retrieveSimpleStreamImageAndConvert(to: location.diskURL, runMode: runMode, progressHandler: progressHandler)
		} else {
			throw ServiceError(String(localized: "unsupported image url: \(options.image)"))
		}

		return options
	}

	static func buildVM(vmName: String, location: VMLocation, options: BuildOptions, runMode: Utils.RunMode, queue: DispatchQueue?, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws -> BuildOptions {
		let options = try await self.cloneImage(vmName: vmName, location: location, options: options, runMode: runMode, progressHandler: progressHandler)

		try await self.build(vmName: vmName, location: location, options: options, runMode: runMode, queue: queue, progressHandler: progressHandler)

		return options
	}
}
