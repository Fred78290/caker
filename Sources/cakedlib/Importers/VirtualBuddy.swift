import Foundation
import GRPCLib
import Virtualization
import CakeAgentLib

/// Reads a VirtualBuddy `.vbvm` bundle. VirtualBuddy stores its configuration as a property
/// list at `.vbdata/Config.plist` inside the bundle, and keeps `HardwareModel`,
/// `MachineIdentifier` and `AuxiliaryStorage` as raw Virtualization.framework files at the
/// bundle root (see insidegui/VirtualBuddy `VBVirtualMachine.swift` and
/// `VBVirtualMachine+Virtualization.swift`). The managed boot disk is named `Disk` with an
/// extension that depends on its format (`img` for raw, `asif` for Apple Sparse Image Format,
/// `dmg`/`sparseimage` for UDIF-backed images).
struct VirtualBuddyImporter: Importer {
	let logger: Logger = .init("VirtualBuddyImporter")

	var needSudo: Bool {
		return false
	}

	var name: String {
		return "VirtualBuddy"
	}

	var source: String {
		return "virtualbuddy"
	}

	private var defaultLibraryURL: URL {
		FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/VirtualBuddy", isDirectory: true)
	}

	func locateVM(source: String) throws -> URL {
		var isDirectory: ObjCBool = false

		if FileManager.default.fileExists(atPath: source, isDirectory: &isDirectory), isDirectory.boolValue {
			return URL(fileURLWithPath: source, isDirectory: true)
		}

		let bundleName = source.hasSuffix(".vbvm") ? source : "\(source).vbvm"
		let url = defaultLibraryURL.appendingPathComponent(bundleName, isDirectory: true)

		guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
			throw ServiceError(String(localized: "No VirtualBuddy virtual machine named \"\(source)\" found in \(defaultLibraryURL.path)"))
		}

		return url
	}

	private static func plist(at url: URL) throws -> [String: Any] {
		guard let dict = NSDictionary(contentsOf: url) as? [String: Any] else {
			throw ServiceError(String(localized: "Unable to read property list \(url.path)"))
		}

		return dict
	}

	private static let managedImageExtensions: [String: Bool] = [
		"img": true,  // raw
		"asif": true,  // Apple Sparse Image Format, directly attachable
		"dmg": false,
		"sparseimage": false,
	]

	func importVM(location: VMLocation, source: String, userName: String, password: String, clearPassword: Bool, sshPrivateKey: String? = nil, passphrase: String? = nil, copyDisk: Bool = true, runMode: Utils.RunMode) throws {
		let bundleURL = try locateVM(source: source)
		let configURL = bundleURL.appendingPathComponent(".vbdata/Config.plist")

		guard try configURL.exists() else {
			throw ServiceError(String(localized: "Config.plist not found in \(bundleURL.path)"))
		}

		let plist = try Self.plist(at: configURL)

		guard let systemType = plist["systemType"] as? String else {
			throw ServiceError(String(localized: "Missing systemType in \(configURL.path)"))
		}

		let os: VirtualizedOS = systemType == "linux" ? .linux : .darwin

		guard let hardware = plist["hardware"] as? [String: Any] else {
			throw ServiceError(String(localized: "Missing hardware section in \(configURL.path)"))
		}

		let cpuCount = hardware["cpuCount"] as? Int ?? 2
		let memorySize = hardware["memorySize"] as? UInt64 ?? UInt64(2) * GiB

		// Note: `storageDevices` is a computed property backed by the plain stored property
		// `_storageDevices`, which is what gets serialized to the property list.
		let storageDevices = (hardware["_storageDevices"] as? [[String: Any]]) ?? []
		guard let bootDevice = storageDevices.first(where: { ($0["isBootVolume"] as? Bool) == true }) ?? storageDevices.first else {
			throw ServiceError(String(localized: "\(source) has no storage device configured"))
		}

		// Swift's synthesized Codable for an enum case with a single unlabeled associated value
		// (`case managedImage(VBManagedDiskImage)`) nests the payload under the "_0" key.
		guard let backing = bootDevice["backing"] as? [String: Any], let managedImage = (backing["managedImage"] as? [String: Any])?["_0"] as? [String: Any], let filename = managedImage["filename"] as? String else {
			throw ServiceError(String(localized: "\(source) does not use a VirtualBuddy-managed boot disk image, which is required for import"))
		}

		guard let bootDiskURL = try findManagedDiskImage(named: filename, in: bundleURL) else {
			throw ServiceError(String(localized: "Boot disk image \"\(filename)\" not found in \(bundleURL.path)"))
		}

		guard Self.managedImageExtensions[bootDiskURL.pathExtension.lowercased()] == true else {
			throw ServiceError(String(localized: "Boot disk image format \".\(bootDiskURL.pathExtension)\" is not supported for import, only raw and ASIF images can be imported"))
		}

		var macAddress: VZMACAddress? = nil
		let networkDevices = (hardware["networkDevices"] as? [[String: Any]]) ?? []
		let networkAttachments: [GRPCLib.BridgeAttachement] = networkDevices.compactMap { network in
			let kind = network["kind"] as? Int ?? 0
			let mac = network["macAddress"] as? String

			if kind == 1 {
				// bridge
				return GRPCLib.BridgeAttachement(network: "bridge", mode: .auto, macAddress: mac)
			}

			if let mac, macAddress == nil {
				macAddress = VZMACAddress(string: mac)
			}

			return GRPCLib.BridgeAttachement(network: "nat", mode: .auto, macAddress: nil)
		}

		let config = CakeConfig(
			location: location.rootURL,
			rootDisk: copyDisk ? nil : bootDiskURL.absoluteURL.path,
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
			cpuCountMin: UInt16(clamping: cpuCount),
			memorySize: memorySize,
			memorySizeMin: VMBuilder.memoryMinSize,
			macAddress: macAddress ?? VZMACAddress.randomLocallyAdministered(),
			screenSize: .standard
		)

		config.useCloudInit = false
		config.agent = false
		config.nested = os == .linux
		config.networks = networkAttachments.isEmpty ? [GRPCLib.BridgeAttachement(network: "nat", mode: .auto, macAddress: nil)] : networkAttachments
		config.sshPrivateKeyPath = sshPrivateKey
		config.sshPrivateKeyPassphrase = passphrase
		config.firstLaunch = true

		if os == .darwin {
			#if arch(arm64)
				let hardwareModelURL = bundleURL.appendingPathComponent("HardwareModel")
				let machineIdentifierURL = bundleURL.appendingPathComponent("MachineIdentifier")
				let auxiliaryStorageURL = bundleURL.appendingPathComponent("AuxiliaryStorage")

				guard try hardwareModelURL.exists(), let hardwareModel = VZMacHardwareModel(dataRepresentation: try Data(contentsOf: hardwareModelURL)) else {
					throw ServiceError(String(localized: "Invalid or missing HardwareModel in \(bundleURL.path)"))
				}

				guard try machineIdentifierURL.exists(), let ecid = VZMacMachineIdentifier(dataRepresentation: try Data(contentsOf: machineIdentifierURL)) else {
					throw ServiceError(String(localized: "Invalid or missing MachineIdentifier in \(bundleURL.path)"))
				}

				guard hardwareModel.isSupported else {
					throw ServiceError(String(localized: "The hardware model of \(source) is not supported on this Mac"))
				}

				config.setECID(ecid)
				config.setHardwareModel(hardwareModel)

				if try auxiliaryStorageURL.exists() {
					try FileManager.default.copyItem(at: auxiliaryStorageURL, to: location.nvramURL)
				} else {
					_ = try VZMacAuxiliaryStorage(creatingStorageAt: location.nvramURL, hardwareModel: hardwareModel, options: [])
				}
			#else
				throw ServiceError(String(localized: "macOS guests can only be imported on Apple Silicon hosts"))
			#endif
		} else {
			_ = try VZEFIVariableStore(creatingVariableStoreAt: location.nvramURL)
		}

		if copyDisk {
			logger.info("Copying VirtualBuddy disk image \(bootDiskURL.path) to \(location.diskURL.path)")
			try FileManager.default.copyItem(at: bootDiskURL, to: location.diskURL)
		} else {
			logger.info("Referencing VirtualBuddy disk image in place at \(bootDiskURL.path)")
		}

		try config.save()
	}

	/// VirtualBuddy stores managed disk images at the bundle root with the format's file
	/// extension appended to the configured filename, e.g. `Disk.img` or `Disk.asif`.
	private func findManagedDiskImage(named filename: String, in bundleURL: URL) throws -> URL? {
		for ext in Self.managedImageExtensions.keys {
			let url = bundleURL.appendingPathComponent(filename).appendingPathExtension(ext)

			if try url.exists() {
				return url
			}
		}

		return nil
	}
}
