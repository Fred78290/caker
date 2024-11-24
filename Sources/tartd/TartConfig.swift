import Foundation
import Virtualization

struct DisplayConfig: Codable {
	var width: Int = 1024
	var height: Int = 768

	init() {
		self.width = 1024
		self.height = 768
	}

	init(from: Dictionary<String, Int>) {
		self.width = from["width"] ?? 1024
		self.height = from["height"] ?? 768
	}

	func to() -> Dictionary<String, Int> {
		var dict: [String:Int] = [:]
		dict["width"] = self.width
		dict["height"] = self.height
		return dict
	}
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

struct TartConfig {
	var config: Dictionary<String, Any>

	var version: Int {
		set { self.config["version"] = newValue }
		get { self.config["version"] as! Int }
	}

	var os: VirtualizedOS {
		set { self.config["os"] = newValue }
		get { self.config["os"] as! VirtualizedOS }
	}

	var arch: HostArchitecture {
		set { self.config["arch"] = newValue }
		get { self.config["arch"] as! HostArchitecture }
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

	var display: DisplayConfig {
		set { self.config["display"] = newValue.to() }
		get { DisplayConfig(from: self.config["display"] as! Dictionary<String, Int>) }
	}

	var displayRefit: Bool? {
		set { self.config["displayRefit"] = newValue }
		get { self.config["displayRefit"] as? Bool }
	}

	var runningArguments: [String] {
		set { self.config["runningArguments"] = newValue }
		get { self.config["runningArguments"] as! [String] }
	}

	init(os: VirtualizedOS,
	     cpuCountMin: Int,
	     memorySizeMin: UInt64,
	     macAddress: VZMACAddress = VZMACAddress.randomLocallyAdministered()) {

		self.config = [:]
		self.version = 1
		self.os = os
		self.cpuCountMin = cpuCountMin
		self.memorySizeMin = memorySizeMin
		self.macAddress = macAddress.string
		self.cpuCount = cpuCountMin
		self.memorySize = memorySizeMin
		self.display = DisplayConfig()
	}

	init(contentsOf: URL) throws {
		self.config = try Dictionary(contentsOf: contentsOf) as [String: Any]
	}

	func save(toURL: URL) throws {
		try config.write(to: toURL)
	}
}
