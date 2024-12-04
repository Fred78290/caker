import Dispatch
import Foundation
import SwiftUI
import Virtualization
import GRPCLib

struct ConfigureHandler: CakedCommand {
	var options: ConfigureOptions

	static func configure(name: String, options: ConfigureOptions, asSystem: Bool) async throws {
		let vmLocation = try StorageLocation(asSystem: runAsSystem).find(name)
		var config = try CakeConfig(baseURL: vmLocation.rootURL)

		if let cpu = options.cpu {
			config.cpuCount = Int(cpu)
		}

		if let memory = options.memory {
			config.memorySize = memory * 1024 * 1024
		}

		if options.randomMAC {
			config.macAddress = VZMACAddress.randomLocallyAdministered().string
		}

		if let displayRefit = options.displayRefit {
			config.displayRefit = displayRefit
		}

		if let autostart = options.autostart {
			config.autostart = autostart
		}

		if let nested = options.nested {
			config.nested = nested
		}

		if let mounts = options.mounts {
			config.mounts = mounts
		}

		if let bridged = options.bridged {
			config.netBridged = bridged
		}

//		if let netSoftnet = options.netSoftnet {
//			config.netSoftnet = netSoftnet
//		}
//
//		if let netSoftnetAllow = options.netSoftnetAllow {
//			config.netSoftnetAllow = netSoftnetAllow
//		}
//
//		if let netHost = options.netHost {
//			config.netHost = netHost
//		}

		if options.resetForwardedPort {
			config.forwardedPort = []
		} else if options.forwardedPort.count > 0 {
			config.forwardedPort = options.forwardedPort
		}

		try config.save(to: vmLocation.configURL)

		if let diskSize = options.diskSize {
			try vmLocation.expandDiskTo(diskSize)
		}
	}

	func run(asSystem: Bool) async throws -> String {
		try await Self.configure(name: self.options.name, options: options, asSystem: asSystem)

		return ""
	}
}
