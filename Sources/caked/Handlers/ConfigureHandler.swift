import Dispatch
import Foundation
import SwiftUI
import Virtualization

protocol ConfigureArguments {
	var name: String { get }
	var cpu: UInt16? { get }
	var memory: UInt64? { get }
	var diskSize: UInt16? { get }
	var displayRefit: Bool? { get }
	var autostart: Bool? { get }
	var nested: Bool? { get }
	var mounts: [String]? { get }
	var bridged: [String]? { get }
	var netSoftnet: Bool? { get }
	var netSoftnetAllow: String? { get }
	var netHost: Bool? { get }
	var randomMAC: Bool { get }
}

struct ConfigureHandler: CakedCommand, ConfigureArguments {
	var name: String
	var cpu: UInt16? = nil
	var memory: UInt64? = nil
	var diskSize: UInt16? = nil
	var displayRefit: Bool? = nil
	var autostart: Bool? = nil
	var nested: Bool? = nil
	var mounts: [String]? = nil
	var bridged: [String]? = nil
	var netSoftnet: Bool? = nil
	var netSoftnetAllow: String? = nil
	var netHost: Bool? = nil
	var randomMAC: Bool = false

	static func configure(name: String, arguments: ConfigureArguments, asSystem: Bool) async throws {
		let vmLocation = try StorageLocation(asSystem: runAsSystem).find(name)
		var config = try CakeConfig(baseURL: vmLocation.rootURL)

		if let cpu = arguments.cpu {
			config.cpuCount = Int(cpu)
		}

		if let memory = arguments.memory {
			config.memorySize = memory * 1024 * 1024
		}

		if arguments.randomMAC {
			config.macAddress = VZMACAddress.randomLocallyAdministered().string
		}

		if let displayRefit = arguments.displayRefit {
			config.displayRefit = displayRefit
		}

		if let autostart = arguments.autostart {
			config.autostart = autostart
		}
		
		if let nested = arguments.nested {
			config.nested = nested
		}
		
		if let mounts = arguments.mounts {
			config.mounts = mounts
		}

		if let bridged = arguments.bridged {
			config.netBridged = bridged
		}
		
		if let netSoftnet = arguments.netSoftnet {
			config.netSoftnet = netSoftnet
		}

		if let netSoftnetAllow = arguments.netSoftnetAllow {
			config.netSoftnetAllow = netSoftnetAllow
		}

		if let netHost = arguments.netHost {
			config.netHost = netHost
		}
		
		try config.save(to: vmLocation.configURL)

		if let diskSize = arguments.diskSize {
			try vmLocation.expandDiskTo(diskSize)
		}
	}

	func run(asSystem: Bool) async throws -> String {
		try await Self.configure(name: self.name, arguments: self, asSystem: asSystem)

		return ""
	}
}
