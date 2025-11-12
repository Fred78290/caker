import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct StopHandler: CakedCommand {
	var request: Caked_StopRequest

	func replyError(error: any Error) -> Caked_Reply {
		Caked_Reply.with {
			$0.vms.stop = Caked_StopReply.with {
				$0.stopped = false
				$0.reason = "\(error)"
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		let result = try CakedLib.StopHandler.stopVMs(all: self.request.all, names: self.request.names.list, force: self.request.force, runMode: runMode)

		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.stop = Caked_StopReply.with {
					$0.stopped = true
					$0.reason = "Success"
					$0.objects = result.map {
						$0.toCaked_StoppedObject()
					}
				}
			}
		}
	}
}
