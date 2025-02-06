import Foundation
import Virtualization
import GRPCLib
import NIOPortForwarding

typealias DisplaySize = Dictionary<String, Int>

extension DisplaySize {
	var width: Int {
		set { self["width"] = newValue }
		get { self["width"]! }
	}

	var height: Int {
		set { self["height"] = newValue }
		get { self["height"]! }
	}
}

enum ConfigFileName: String {
	case config = "config.json"
	case cake = "cake.json"
}

enum VirtualizedOS: String, Codable {
	case darwin
	case linux
}

struct CakeConfig {
	var config: Dictionary<String, Any>
	var cake: Dictionary<String, Any>
	let location: URL

	var version: Int {
		set { self.config["version"] = newValue }
		get { self.config["version"] as! Int }
	}

	var os: VirtualizedOS {
		set { self.config["os"] = newValue.rawValue }
		get {
			let os: String? = self.config["os"] as? String

			if let os = os {
				return VirtualizedOS(rawValue: os)!
			}

			return .linux
		}
	}

	var arch: Architecture {
		set { self.config["arch"] = newValue.rawValue }
		get {
			let arch: String? = self.config["arch"] as? String

			if let arch = arch {
				return Architecture(rawValue: arch)
			}

			return Architecture.current()
		}
	}

	var cpuCountMin: Int {
		set { self.config["cpuCountMin"] = newValue }
		get { self.config["cpuCountMin"] as! Int }
	}


	var ecid: VZMacMachineIdentifier {
		set {
				self.config["ecid"] = newValue.dataRepresentation.base64EncodedString()
			}
		get {
				if let ecid = self.config["ecid"] as? String {
					if let ecid = VZMacMachineIdentifier(dataRepresentation: Data(base64Encoded: ecid)!) {
						return ecid
					}
				}

				return VZMacMachineIdentifier()
			}
	}

	var hardwareModel: VZMacHardwareModel? {
		set {
				self.config["hardwareModel"] = newValue!.dataRepresentation.base64EncodedString()
			}
		get {
				if let hardwareModel = self.config["hardwareModel"] as? String {
					if let hardwareModel = VZMacHardwareModel(dataRepresentation: Data(base64Encoded: hardwareModel)!) {
						return hardwareModel
					}
				}

				return nil
			}
	}

	var cpuCount: Int {
		set { self.config["cpuCount"] = newValue }
		get { self.config["cpuCount"] as! Int }
	}

	var memorySizeMin: UInt64 {
		set { self.config["memorySizeMin"] = newValue }
		get { self.config["memorySizeMin"] as! UInt64 }
	}

	var memorySize: UInt64 {
		set { self.config["memorySize"] = newValue }
		get { self.config["memorySize"] as! UInt64 }
	}

	var macAddress: VZMACAddress? {
		set { self.config["macAddress"] = newValue }
		get { if let addr = self.config["macAddress"] as? String {
				return VZMACAddress(string: addr)
			}

			return nil
		}
	}

	var displayRefit: Bool {
		set { self.config["displayRefit"] = newValue }
		get { self.config["displayRefit"] as? Bool ?? false}
	}

	var configuredUser: String {
		set { self.cake["configuredUser"] = newValue }
		get { self.cake["configuredUser"] as? String ?? "admin" }
	}

	var autostart: Bool {
		set { self.cake["autostart"] = newValue }
		get { self.cake["autostart"] as? Bool ?? false }
	}

	var nested: Bool {
		set { self.cake["nested"] = newValue }
		get { self.cake["nested"] as? Bool ?? false }
	}

	var disks: [DiskAttachement] {
		set { self.cake["disks"] = newValue.map{$0.description} }
		get {
			guard let mounts:[String] = self.cake["disks"] as? [String] else {
				return []
			}

			return mounts.compactMap { DiskAttachement(argument: $0) }
		}
	}

	var mounts: [DirectorySharingAttachment] {
		set { self.cake["mounts"] = newValue.map{$0.description} }
		get {
			guard let mounts:[String] = self.cake["mounts"] as? [String] else {
				return []
			}

			return mounts.compactMap { DirectorySharingAttachment(argument: $0) }
		}
	}

	var networks: [BridgeAttachement] {
		set { self.cake["networks"] = newValue.map{$0.description} }
		get {
			guard let mounts:[String] = self.cake["networks"] as? [String] else {
				return []
			}

			return mounts.compactMap { BridgeAttachement(argument: $0) }
		}
	}

	var useCloudInit: Bool {
		set { self.cake["cloud-init"] = newValue }
		get { self.cake["cloud-init"] as? Bool ?? false}
	}

	var sockets: [SocketDevice] {
		set { self.cake["sockets"] = newValue.map{$0.description} }
		get {
			guard let mounts:[String] = self.cake["sockets"] as? [String] else {
				return []
			}

			return mounts.compactMap { SocketDevice(argument: $0) }
		}
	}

	var console: ConsoleAttachment? {
		set { self.cake["console"] = newValue?.description }
		get { guard let consoleURL: String = self.cake["console"] as? String else {
				return nil
			}

			return ConsoleAttachment(argument: consoleURL)
		}
	}

	var forwardedPorts: [ForwardedPort] {
		set { self.cake["forwardedPorts"] = newValue.map{$0.description} }
		get {
			guard let mounts:[String] = self.cake["forwardedPorts"] as? [String] else {
				return []
			}

			return mounts.compactMap { ForwardedPort(argument: $0) }
		}
	}

	var runningIP: String? {
		set { self.cake["runningIP"] = newValue }
		get { self.cake["runningIP"] as? String ?? nil }
	}

	var nestedVirtualization: Bool {
		get {
			if self.os == .linux && Utils.isNestedVirtualizationSupported() {
				return self.nested
			}

			return false
		}
	}

	var display: DisplaySize {
		set { self.config["display"] = newValue }
		get { self.config["display"] as! DisplaySize }
	}

	init(baseURL: URL,
		 os: VirtualizedOS,
	     autostart: Bool,
	     configuredUser: String,
	     displayRefit: Bool,
	     cpuCountMin: Int,
	     memorySizeMin: UInt64,
	     macAddress: VZMACAddress = VZMACAddress.randomLocallyAdministered()) {

		var display = DisplaySize()

		display.width = 1024
		display.height = 768

		self.config = Dictionary<String, Any>()
		self.cake = Dictionary<String, Any>()
		self.version = 1
		self.os = os
		self.cpuCountMin = cpuCountMin
		self.memorySizeMin = memorySizeMin
		self.macAddress = macAddress
		self.cpuCount = cpuCountMin
		self.memorySize = memorySizeMin
		self.displayRefit = displayRefit
		self.configuredUser = configuredUser
		self.autostart = autostart
		self.display = display
		self.location = baseURL
	}

	init(baseURL: URL) throws {
		self.location = baseURL
		self.config = try Dictionary(contentsOf: URL(fileURLWithPath: ConfigFileName.config.rawValue, relativeTo: baseURL)) as [String: Any]
		self.cake = try Dictionary(contentsOf: URL(fileURLWithPath: ConfigFileName.cake.rawValue, relativeTo: baseURL)) as [String: Any]
	}

	func save(to: URL) throws {
		self.location = to
		try self.config.write(to: URL(fileURLWithPath: ConfigFileName.config.rawValue, relativeTo: to))
		try self.cake.write(to: URL(fileURLWithPath: ConfigFileName.cake.rawValue, relativeTo: to))
	}

	mutating func resetMacAddress() {
		self.macAddress = VZMACAddress.randomLocallyAdministered()
	}

	func platform(nvramURL: URL, needsNestedVirtualization: Bool) throws -> GuestPlateForm {
		switch self.os {
		case .darwin:
			return DarwinPlateform(nvramURL: nvramURL, ecid: self.ecid, hardwareModel: self.hardwareModel!)
		case .linux:
			return LinuxPlateform(nvramURL: nvramURL, needsNestedVirtualization: needsNestedVirtualization)
		}
	}
}
