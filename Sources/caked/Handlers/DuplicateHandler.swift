import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct DuplicateHandler: CakedCommandAsync {
	var request: Caked_DuplicateRequest

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.duplicated = .with {
					$0.duplicated = false
					$0.reason = error.reason
				}
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) async -> Caked_Reply {
		let reply = await CakedLib.DuplicateHandler.duplicate(from: self.request.from, to: self.request.to, resetMacAddress: self.request.resetMacAddress, runMode: runMode)

		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.duplicated = reply.caked
			}
		}
	}
}
