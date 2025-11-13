import ArgumentParser
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIOCore

struct WaitIPHandler: CakedCommand {
	var name: String
	var wait: Int

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.waitip = .with {
					$0.success = false
					$0.reason = "\(error)"
				}
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.waitip = CakedLib.WaitIPHandler.waitIP(name: name, wait: wait, runMode: runMode).caked
			}
		}
	}

}
