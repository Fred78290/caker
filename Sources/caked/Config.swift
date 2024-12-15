import Foundation
import Virtualization
import GRPCLib

enum ConfigFileName: String {
	case config = "config.json"
	case cake = "cake.json"
}

enum VirtualizedOS: String, Codable {
	case darwin
	case linux
}

enum HostArchitecture: String, Codable {
	case arm64
	case amd64

	static func current() -> HostArchitecture {
		#if arch(arm64)
			return .arm64
		#elseif arch(x86_64)
			return .amd64
		#endif
	}
}

struct CakeConfig {
	var config: Dictionary<String, Any>
	var cake: Dictionary<String, Any>

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

	var arch: HostArchitecture {
		set { self.config["arch"] = newValue.rawValue }
		get {
			let arch: String? = self.config["arch"] as? String

			if let arch = arch {
				return HostArchitecture(rawValue: arch)!
			}

			return HostArchitecture.current()
		}
	}

	var cpuCountMin: Int {
		set { self.config["cpuCountMin"] = newValue }
		get { self.config["cpuCountMin"] as! Int }
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

	var macAddress: String? {
		set { self.config["macAddress"] = newValue }
		get { self.config["macAddress"] as? String }
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

	var mounts: [String] {
		set { self.cake["mounts"] = newValue }
		get { self.cake["mounts"] as? [String] ?? []}
	}

	var netBridged: [String] {
		set { self.cake["netBridged"] = newValue }
		get { self.cake["netBridged"] as? [String] ?? []}
	}

	var useCloudInit: Bool {
		set { self.cake["cloud-init"] = newValue }
		get { self.cake["cloud-init"] as? Bool ?? false}
	}

//	var netSoftnet: Bool {
//		set { self.cake["netSoftnet"] = newValue }
//		get { self.cake["netSoftnet"] as? Bool ?? false}
//	}
//
//	var netHost: Bool {
//		set { self.cake["netHost"] = newValue }
//		get { self.cake["netHost"] as? Bool ?? false }
//	}
//
//	var netSoftnetAllow: String? {
//		set { self.cake["netSoftnetAllow"] = newValue }
//		get { self.cake["netSoftnetAllow"] as? String ?? nil }
//	}

	var forwardedPort: [ForwardedPort] {
		set { self.cake["forwardedPort"] = newValue.description }
		get {
			if let forwardedPort = self.cake["forwardedPort"] as? [String] {
				return forwardedPort.map { value in 
					return ForwardedPort(argument: value)
				}
			}

			return []
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

	init(os: VirtualizedOS,
	     autostart: Bool,
	     configuredUser: String,
	     displayRefit: Bool,
	     cpuCountMin: Int,
	     memorySizeMin: UInt64,
	     macAddress: VZMACAddress = VZMACAddress.randomLocallyAdministered()) {

		var display = Dictionary<String, Any>()

		display["width"] = 1024
		display["height"] = 768

		self.config = Dictionary<String, Any>()
		self.cake = Dictionary<String, Any>()
		self.version = 1
		self.os = os
		self.cpuCountMin = cpuCountMin
		self.memorySizeMin = memorySizeMin
		self.macAddress = macAddress.string
		self.cpuCount = cpuCountMin
		self.memorySize = memorySizeMin
		self.displayRefit = displayRefit
		self.configuredUser = configuredUser
		self.autostart = autostart

		self.config["display"] = display
	}

	init(baseURL: URL) throws {
		self.config = try Dictionary(contentsOf: URL(fileURLWithPath: ConfigFileName.config.rawValue, relativeTo: baseURL)) as [String: Any]
		self.cake = try Dictionary(contentsOf: URL(fileURLWithPath: ConfigFileName.cake.rawValue, relativeTo: baseURL)) as [String: Any]
	}

	func save(to: URL) throws {
		try self.config.write(to: URL(fileURLWithPath: ConfigFileName.config.rawValue, relativeTo: to))
		try self.cake.write(to: URL(fileURLWithPath: ConfigFileName.cake.rawValue, relativeTo: to))
	}
}
