import ArgumentParser
import Foundation
import SystemConfiguration
import GRPCLib

struct WaitIPHandler: CakedCommand {
	var name: String
	var wait: UInt16

	static func waitIP(name: String, wait: UInt16, asSystem: Bool) throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)
		let config = try CakeConfig(baseURL: vmLocation.configURL)
		let arguments: [String]

		if config.netBridged.isEmpty {
			arguments = [ name, "--wait=\(wait)"]
		} else {
			arguments = [ name, "--wait=\(wait)", "--resolver=arp"]
		}

		return try Shell.runTart(command: "ip", arguments: arguments)
	}

	mutating func run(asSystem: Bool) async throws -> String {
		return try Self.waitIP(name: self.name, wait: self.wait, asSystem: runAsSystem)
	}

}
