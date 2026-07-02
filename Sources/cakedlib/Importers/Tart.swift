import Foundation
import GRPCLib
import Virtualization
import CakeAgentLib

/// Mirrors the subset of Tart's `config.json` (see cirruslabs/tart `VMConfig.swift`) that is
/// needed to recreate the virtual machine. Tart stores VMs at `~/.tart/vms/<name>/` (or
/// `$TART_HOME/vms/<name>/`) as `config.json`, `disk.img` and `nvram.bin`.
private struct TartVMConfig: Decodable {
	var os: String
	var cpuCountMin: Int
	var cpuCount: Int?
	var memorySizeMin: UInt64
	var memorySize: UInt64?
	var macAddress: String
	var ecid: String?
	var hardwareModel: String?
	var diskFormat: String?
}

struct TartImporter: Importer {
	let logger: Logger = .init("TartImporter")

	var needSudo: Bool {
		return false
	}

	var supportsInPlaceDisk: Bool {
		return true
	}

	var name: String {
		return "Tart"
	}

	var source: String {
		return "tart"
	}

	private var tartHomeDir: URL {
		if let custom = ProcessInfo.processInfo.environment["TART_HOME"], custom.isEmpty == false {
			return URL(fileURLWithPath: custom, isDirectory: true)
		}

		return FileManager.realHomeDirectoryForCurrentUser.appendingPathComponent(".tart", isDirectory: true)
	}

	func locateVM(source: String) throws -> URL {
		var isDirectory: ObjCBool = false

		if FileManager.default.fileExists(atPath: source, isDirectory: &isDirectory), isDirectory.boolValue {
			return URL(fileURLWithPath: source, isDirectory: true)
		}

		let url = tartHomeDir.appendingPathComponent("vms", isDirectory: true).appendingPathComponent(source, isDirectory: true)

		guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
			throw ServiceError(String(localized: "No Tart virtual machine named \"\(source)\" found in \(tartHomeDir.appendingPathComponent("vms", isDirectory: true).path)"))
		}

		return url
	}

	func importVM(location: VMLocation, source: String, userName: String, password: String, clearPassword: Bool, sshPrivateKey: String? = nil, passphrase: String? = nil, copyDisk: Bool = true, runMode: Utils.RunMode) throws {
		let vmDir = try locateVM(source: source)
		let configURL = vmDir.appendingPathComponent("config.json")
		let diskURL = vmDir.appendingPathComponent("disk.img")
		let nvramURL = vmDir.appendingPathComponent("nvram.bin")

		guard try configURL.exists() else {
			throw ServiceError(String(localized: "config.json not found in \(vmDir.path)"))
		}

		guard try diskURL.exists() else {
			throw ServiceError(String(localized: "disk.img not found in \(vmDir.path)"))
		}

		let tartConfig = try JSONDecoder().decode(TartVMConfig.self, from: try Data(contentsOf: configURL))
		let os: VirtualizedOS = tartConfig.os == "darwin" ? .darwin : .linux

		let config = CakeConfig(
			location: location.rootURL,
			rootDisk: copyDisk ? nil : diskURL.absoluteURL.path,
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
			cpuCountMin: UInt16(clamping: tartConfig.cpuCountMin),
			memorySize: tartConfig.memorySize ?? tartConfig.memorySizeMin,
			memorySizeMin: tartConfig.memorySizeMin,
			macAddress: VZMACAddress(string: tartConfig.macAddress) ?? VZMACAddress.randomLocallyAdministered(),
			screenSize: .standard
		)

		config.cpuCount = max(UInt16(clamping: tartConfig.cpuCount ?? tartConfig.cpuCountMin), config.cpuCountMin)
		config.useCloudInit = false
		config.agent = false
		config.nested = os == .linux && Utils.isNestedVirtualizationSupported()
		config.networks = [GRPCLib.BridgeAttachement(network: "nat", mode: .auto, macAddress: nil)]
		config.sshPrivateKeyPath = sshPrivateKey
		config.sshPrivateKeyPassphrase = passphrase
		config.firstLaunch = true

		if os == .darwin {
			#if arch(arm64)
				guard let encodedECID = tartConfig.ecid, let ecidData = Data(base64Encoded: encodedECID), let ecid = VZMacMachineIdentifier(dataRepresentation: ecidData) else {
					throw ServiceError(String(localized: "Invalid or missing machine identifier (ecid) in \(configURL.path)"))
				}

				guard let encodedHardwareModel = tartConfig.hardwareModel, let hardwareModelData = Data(base64Encoded: encodedHardwareModel), let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData) else {
					throw ServiceError(String(localized: "Invalid or missing hardware model in \(configURL.path)"))
				}

				guard hardwareModel.isSupported else {
					throw ServiceError(String(localized: "The hardware model of \(source) is not supported on this Mac"))
				}

				config.setECID(ecid)
				config.setHardwareModel(hardwareModel)
			#else
				throw ServiceError(String(localized: "macOS guests can only be imported on Apple Silicon hosts"))
			#endif
		}

		if try nvramURL.exists() {
			try FileManager.default.copyItem(at: nvramURL, to: location.nvramURL)
		} else if os == .darwin {
			#if arch(arm64)
				_ = try VZMacAuxiliaryStorage(creatingStorageAt: location.nvramURL, hardwareModel: config.getHardwareModel()!, options: [])
			#endif
		} else {
			_ = try VZEFIVariableStore(creatingVariableStoreAt: location.nvramURL)
		}

		if copyDisk {
			logger.info("Copying Tart disk image \(diskURL.path) to \(location.diskURL.path)")
			try FileManager.default.copyItem(at: diskURL, to: location.diskURL)
		} else {
			logger.info("Referencing Tart disk image in place at \(diskURL.path)")
		}

		try config.save()
	}
}
