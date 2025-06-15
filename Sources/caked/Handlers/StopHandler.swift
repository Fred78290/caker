import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import CakedLib


struct StopHandler: CakedCommand {
	var request: Caked_StopRequest

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		let result = try CakedLib.StopHandler.stopVMs(all: self.request.all, names: self.request.names.list, force: self.request.force, runMode: runMode)

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
