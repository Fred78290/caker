import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import Shout
import SystemConfiguration

struct StopHandler: CakedCommand {
	var request: Caked_StopRequest

	static func stopVM(name: String, force: Bool, runMode: Utils.RunMode) throws -> StopReply {
		let vmLocation = try StorageLocation(runMode: runMode).find(name)

		if vmLocation.status == .running {
			try vmLocation.stopVirtualMachine(force: force, runMode: runMode)
			return StopReply(name: name, status: "VM \(name) stopped", stopped: true, reason: "")
		}

		return StopReply(name: name, status: "VM \(name) is not running", stopped: false, reason: "VM is not running")
	}

	static func stopVMs(all: Bool, names: [String], force: Bool, runMode: Utils.RunMode) throws -> [StopReply] {
		if all {
			return try StorageLocation(runMode: runMode).list().compactMap { (key: String, value: VMLocation) in
				if value.status == .running {
					try value.stopVirtualMachine(force: force, runMode: runMode)

					return StopReply(name: key, status: "VM \(key) stopped", stopped: true, reason: "")
				}

				return nil
			}
		} else {
			return try names.compactMap {
				try StopHandler.stopVM(name: $0, force: force, runMode: runMode)
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		let result = try StopHandler.stopVMs(all: self.request.all, names: self.request.names.list, force: self.request.force, runMode: runMode)

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
