import ArgumentParser
import Foundation
import SystemConfiguration
import GRPCLib
import Shout
import NIOCore

struct StopHandler: CakedCommand {
	var name: String
	var force: Bool = false

	static func stopVM(name: String, force: Bool, asSystem: Bool) throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)

		try vmLocation.stopVirtualMachine(force: force, asSystem: asSystem)

		return "VM \(name) stopped"
	}

	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		let message = try StopHandler.stopVM(name: self.name, force: self.force, asSystem: runAsSystem)

		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.message = message
			}
		}
	}
}
