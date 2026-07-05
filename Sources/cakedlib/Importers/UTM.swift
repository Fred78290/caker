import Foundation
import GRPCLib
import Virtualization
import CakeAgentLib

/// Reads a UTM `.utm` bundle (`config.plist` + `Data/` folder) that uses UTM's Apple
/// Virtualization backend. See utmapp/UTM `Configuration/UTMAppleConfiguration*.swift`.
///
/// UTM's QEMU backend (used for non-Apple-Silicon guests or emulated architectures) is not
/// supported since it has no equivalent in this project, which is built directly on top of
/// Virtualization.framework.
struct UTMImporter: Importer {
	let logger: Logger = .init("UTMImporter")

	var needSudo: Bool {
		return false
	}

	var supportsInPlaceDisk: Bool {
		return true
	}

	var name: String {
		return "UTM"
	}

	var source: String {
		return "utm"
	}

	private var candidateLibraryURLs: [URL] {
		let home = FileManager.realHomeDirectoryForCurrentUser

		return [
			home.appendingPathComponent("Library/Containers/com.utmapp.UTM/Data/Documents", isDirectory: true),
			home.appendingPathComponent("Documents", isDirectory: true),
		]
	}

	func locateVM(source: String) throws -> URL {
		var isDirectory: ObjCBool = false

		if FileManager.default.fileExists(atPath: source, isDirectory: &isDirectory), isDirectory.boolValue {
			return URL(fileURLWithPath: source, isDirectory: true)
		}

		let bundleName = source.hasSuffix(".utm") ? source : "\(source).utm"

		for candidate in candidateLibraryURLs {
			let url = candidate.appendingPathComponent(bundleName, isDirectory: true)

			if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
				return url
			}
		}

		throw ServiceError(String(localized: "No UTM virtual machine named \"\(source)\" found"))
	}

	private static func plist(at url: URL) throws -> [String: Any] {
		guard let dict = NSDictionary(contentsOf: url) as? [String: Any] else {
			throw ServiceError(String(localized: "Unable to read property list \(url.path)"))
		}

		return dict
	}

	func importVM(location: VMLocation, source: String, userName: String, password: String, clearPassword: Bool, sshPrivateKey: String? = nil, passphrase: String? = nil, copyDisk: Bool = true, runMode: Utils.RunMode) throws {
		let bundleURL = try locateVM(source: source)
		let configURL = bundleURL.appendingPathComponent("config.plist")
		let dataURL = bundleURL.appendingPathComponent("Data", isDirectory: true)

		guard try configURL.exists() else {
			throw ServiceError(String(localized: "config.plist not found in \(bundleURL.path)"))
		}

		let plist = try Self.plist(at: configURL)

		guard (plist["Backend"] as? String) == "Apple" else {
			throw ServiceError(String(localized: "Only UTM virtual machines using the Apple Virtualization backend can be imported"))
		}

		guard let system = plist["System"] as? [String: Any] else {
			throw ServiceError(String(localized: "Missing System section in \(configURL.path)"))
		}

		guard let boot = system["Boot"] as? [String: Any], let operatingSystem = boot["OperatingSystem"] as? String else {
			throw ServiceError(String(localized: "Missing Boot section in \(configURL.path)"))
		}

		let os: VirtualizedOS

		switch operatingSystem {
		case "macOS":
			os = .darwin
		case "Linux":
			os = .linux
		default:
			throw ServiceError(String(localized: "UTM virtual machine \(source) has no operating system configured"))
		}

		let cpuCount = system["CPUCount"] as? Int ?? 0
		let memorySizeMib = system["MemorySize"] as? Int ?? 4096
		let drives = (plist["Drive"] as? [[String: Any]]) ?? []
		let networks = (plist["Network"] as? [[String: Any]]) ?? []

		guard memorySizeMib > 0 else {
			throw ServiceError(String(localized: "Invalid memory size \(memorySizeMib) MiB in \(configURL.path)"))
		}

		// The boot disk is the first drive backed by an image in the Data folder; entries
		// without an ImageName (external or removable drives) cannot be the boot volume.
		guard let bootDrive = drives.first(where: { $0["ImageName"] is String }), let imageName = bootDrive["ImageName"] as? String else {
			throw ServiceError(String(localized: "UTM virtual machine \(source) has no boot drive configured"))
		}

		let bootDiskURL = dataURL.appendingPathComponent(imageName)

		guard try bootDiskURL.exists() else {
			throw ServiceError(String(localized: "Boot disk image \(bootDiskURL.path) not found"))
		}

		let asifFormat = bootDiskURL.asifDisk

		if asifFormat {
            logger.info("Detected ASIF disk format for \(bootDiskURL.lastPathComponent)")
        }

		var macAddress: VZMACAddress? = nil
		let networkAttachments: [GRPCLib.BridgeAttachement] = networks.compactMap { network in
			let mode = network["Mode"] as? String ?? "Shared"
			let mac = network["MacAddress"] as? String

			if mode == "Bridged" {
				let bridgeInterface = network["BridgeInterface"] as? String ?? "nat"

				return GRPCLib.BridgeAttachement(network: bridgeInterface, mode: .auto, macAddress: mac)
			}

			if let mac, macAddress == nil {
				macAddress = VZMACAddress(string: mac)
			}

			return GRPCLib.BridgeAttachement(network: "nat", mode: .auto, macAddress: nil)
		}

		let config = CakeConfig(
			location: location.rootURL,
			rootDisk: copyDisk ? nil : bootDiskURL.absoluteURL.path,
			diskFormat: asifFormat ? .asif : .raw,
			os: os,
			autostart: false,
			configuredUser: userName,
			configuredPassword: password,
			configuredGroup: "adm",
			configuredGroups: ["sudo"],
			configuredPlatform: os == .darwin ? .macos : .unknown,
			clearPassword: clearPassword,
			displayRefit: true,
			ifname: false,
			cpuCountMin: cpuCount > 0 ? UInt16(clamping: cpuCount) : 2,
			memorySize: UInt64(memorySizeMib) * MoB,
			memorySizeMin: VMBuilder.memoryMinSize,
			macAddress: macAddress ?? VZMACAddress.randomLocallyAdministered(),
			screenSize: .standard
		)

		config.useCloudInit = false
		config.agent = false
		config.nested = os == .linux && Utils.isNestedVirtualizationSupported()
		config.networks = networkAttachments.isEmpty ? [GRPCLib.BridgeAttachement(network: "nat", mode: .auto, macAddress: nil)] : networkAttachments
		config.sshPrivateKeyPath = sshPrivateKey
		config.sshPrivateKeyPassphrase = passphrase
		config.firstLaunch = true

		if os == .darwin {
			#if arch(arm64)
				guard let macPlatform = system["MacPlatform"] as? [String: Any] else {
					throw ServiceError(String(localized: "Missing MacPlatform section in \(configURL.path)"))
				}

				guard let hardwareModelData = macPlatform["HardwareModel"] as? Data, let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData) else {
					throw ServiceError(String(localized: "Invalid or missing hardware model in \(configURL.path)"))
				}

				guard let machineIdentifierData = macPlatform["MachineIdentifier"] as? Data, let ecid = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
					throw ServiceError(String(localized: "Invalid or missing machine identifier in \(configURL.path)"))
				}

				guard hardwareModel.isSupported else {
					throw ServiceError(String(localized: "The hardware model of \(source) is not supported on this Mac"))
				}

				config.setECID(ecid)
				config.setHardwareModel(hardwareModel)

				let auxiliaryStoragePath = (macPlatform["AuxiliaryStoragePath"] as? String) ?? "AuxiliaryStorage"
				let auxiliaryStorageURL = dataURL.appendingPathComponent(auxiliaryStoragePath)

				if try auxiliaryStorageURL.exists() {
					try FileManager.default.copyItem(at: auxiliaryStorageURL, to: location.nvramURL)
				} else {
					_ = try VZMacAuxiliaryStorage(creatingStorageAt: location.nvramURL, hardwareModel: hardwareModel, options: [])
				}
			#else
				throw ServiceError(String(localized: "macOS guests can only be imported on Apple Silicon hosts"))
			#endif
		} else {
			let hasUefiBoot = (boot["UEFIBoot"] as? Bool) ?? false
			let efiVariableStoragePath = boot["EfiVariableStoragePath"] as? String

			if hasUefiBoot, let efiVariableStoragePath {
				let efiVariableStorageURL = dataURL.appendingPathComponent(efiVariableStoragePath)

				if try efiVariableStorageURL.exists() {
					try FileManager.default.copyItem(at: efiVariableStorageURL, to: location.nvramURL)
				} else {
					_ = try VZEFIVariableStore(creatingVariableStoreAt: location.nvramURL)
				}
			} else {
				throw ServiceError(String(localized: "UTM Linux virtual machine \(source) does not use UEFI boot, which is required for import"))
			}
		}

		if drives.count > 1 {
			logger.warn("UTM virtual machine \(source) has additional drives that were not imported")
		}

		if copyDisk {
			logger.info("Copying UTM disk image \(bootDiskURL.path) to \(location.diskURL.path)")
			try FileManager.default.copyItem(at: bootDiskURL, to: location.diskURL)
		} else {
			logger.info("Referencing UTM disk image in place at \(bootDiskURL.path)")
		}

		try config.save()
	}
}
