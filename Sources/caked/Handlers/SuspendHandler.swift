import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct SuspendHandler: CakedCommand {
	var request: Caked_SuspendRequest

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		let result = try CakedLib.SuspendHandler.suspendVMs(names: self.request.names, runMode: runMode)

		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.suspend = Caked_SuspendReply.with {
					$0.objects = result.map {
						$0.toCaked_SuspendedObject()
					}
				}
			}
		}
	}
}
