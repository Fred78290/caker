import ArgumentParser
import Foundation
import GRPCLib
import Logging
import NIO

struct CloneHandler: CakedCommand {
	var request: Caked_CloneRequest

	static func clone(name: String, from: String, concurrency: UInt = 4, deduplicate: Bool = false, insecure: Bool = false, direct: Bool, asSystem: Bool) throws -> String {
		if StorageLocation(asSystem: asSystem).exists(name) {
			throw ServiceError("VM already exists")
		}

		if Root.tartIsPresent == false {
			throw ServiceError("Tart is not installed")
		}

		var arguments = [from, name]

		if concurrency != 4 {
			arguments.append("--concurrency=\(concurrency)")
		}

		if insecure {
			arguments.append("--insecure")
		}

		if deduplicate {
			arguments.append("--deduplicate")
		}

		try Shell.runTart(command: "clone", arguments: arguments, direct: direct, asSystem: asSystem)

		let location = try StorageLocation(asSystem: asSystem).find(name)
		let cakeConfig = try CakeConfig(location: location.rootURL, configuredUser: "admin", configuredPassword: "admin")

		try cakeConfig.save()

		return "VM \(name) cloned"
	}

	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		return try Caked_Reply.with { reply in
			reply.vms = try Caked_VirtualMachineReply.with {
				$0.message = try Self.clone(name: self.request.targetName, from: self.request.sourceName, concurrency: UInt(self.request.concurrency), deduplicate: self.request.deduplicate, insecure: self.request.insecure, direct: false, asSystem: asSystem)
			}
		}
	}
}
