import Foundation
import Virtualization

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

	var macAddress: String {
		set { self.config["macAddress"] = newValue }
		get { self.config["macAddress"] as! String }
	}

	var displayRefit: Bool? {
		set { self.config["displayRefit"] = newValue }
		get { self.config["displayRefit"] as? Bool }
	}

	init(os: VirtualizedOS,
	     displayRefit: Bool,
	     cpuCountMin: Int,
	     memorySizeMin: UInt64,
	     macAddress: VZMACAddress = VZMACAddress.randomLocallyAdministered()) {

		var display = Dictionary<String, Any>()

		display["width"] = 1024
		display["height"] = 768

		self.config = Dictionary<String, Any>()
		self.version = 1
		self.os = os
		self.cpuCountMin = cpuCountMin
		self.memorySizeMin = memorySizeMin
		self.macAddress = macAddress.string
		self.cpuCount = cpuCountMin
		self.memorySize = memorySizeMin
		self.displayRefit = displayRefit

		self.config["display"] = display
	}

	init(contentsOf: URL) throws {
		self.config = try Dictionary(contentsOf: contentsOf) as [String: Any]
	}

	func save(toURL: URL) throws {
		//let jsonData = try NSJSONSerialization.dataWithJSONObject(self.config, options: .prettyPrinted)
		//let jsonData = try JSONSerialization.data(withJSONObject: self.config, options: .prettyPrinted)
		//try jsonData.write(to: toURL)
		try self.config.write(to: toURL)
	}
}
