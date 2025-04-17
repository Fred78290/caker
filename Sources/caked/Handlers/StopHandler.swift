import ArgumentParser
import Foundation
import SystemConfiguration
import GRPCLib
import Shout
import NIOCore

struct StopHandler: CakedCommand {
	var request: Caked_StopRequest

	static func stopVM(name: String, force: Bool, asSystem: Bool) throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)

		if vmLocation.status == .running {
			try vmLocation.stopVirtualMachine(force: force, asSystem: asSystem)
			return "VM \(name) stopped"
		}

		return "VM \(name) is not running"
	}

	static func stopVMs(all: Bool, names: [String], force: Bool, asSystem: Bool) throws -> [String] {
		if all {
			return try StorageLocation(asSystem: false).list().compactMap { (key: String, value: VMLocation) in
				if value.status == .running {
					try value.stopVirtualMachine(force: force, asSystem: asSystem)

					return "VM \(key) stopped"
				}

				return nil
			}
		} else {
			return try names.compactMap {
				try StopHandler.stopVM(name: $0, force: force, asSystem: asSystem)
			}
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		let message = try StopHandler.stopVMs(all: self.request.all, names: self.request.names.list, force: self.request.force, asSystem: runAsSystem)

		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.message = message.joined(separator: "\n")
			}
		}
	}
}
