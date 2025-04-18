import ArgumentParser
import Foundation
import SystemConfiguration
import GRPCLib
import Shout
import NIOCore

struct StopHandler: CakedCommand {
	var request: Caked_StopRequest

	static func stopVM(name: String, force: Bool, asSystem: Bool) throws -> StopReply {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)

		if vmLocation.status == .running {
			try vmLocation.stopVirtualMachine(force: force, asSystem: asSystem)
			return StopReply(name: name, status: "VM \(name) stopped", stopped: true)
		}

		return StopReply(name: name, status: "VM \(name) is not running", stopped: false)
	}

	static func stopVMs(all: Bool, names: [String], force: Bool, asSystem: Bool) throws -> [StopReply] {
		if all {
			return try StorageLocation(asSystem: asSystem).list().compactMap { (key: String, value: VMLocation) in
				if value.status == .running {
					try value.stopVirtualMachine(force: force, asSystem: asSystem)

					return StopReply(name: key, status: "VM \(key) stopped", stopped: true)
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
		let result = try StopHandler.stopVMs(all: self.request.all, names: self.request.names.list, force: self.request.force, asSystem: asSystem)

		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.stop = Caked_StopReply.with {
					$0.objects = result.map {
						$0.toCaked_StoppedObject()
					}
				}
			}
		}
	}
}
