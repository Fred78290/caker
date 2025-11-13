import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct SuspendHandler: CakedCommand {
	var request: Caked_SuspendRequest

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.suspend = Caked_SuspendReply.with {
					$0.success = false
					$0.reason = "\(error)"
				}
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.suspend = CakedLib.SuspendHandler.suspendVMs(names: self.request.names, runMode: runMode).caked
			}
		}
	}
}
