import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct DuplicateHandler: CakedCommand {
	var request: Caked_DuplicateRequest

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.duplicated = .with {
					$0.duplicated = false
					$0.reason = "\(error)"
				}
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.duplicated = CakedLib.DuplicateHandler.duplicate(from: self.request.from, to: self.request.to, resetMacAddress: self.request.resetMacAddress, runMode: runMode).caked
			}
		}
	}
}
