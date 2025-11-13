import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import NIOCore
import SystemConfiguration

struct ListHandler: CakedCommand {
	let vmonly: Bool

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.list = Caked_VirtualMachineInfoReply.with {
					$0.success = false
					$0.reason = "\(error)"
				}
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.list = CakedLib.ListHandler.list(vmonly: self.vmonly, runMode: runMode).caked
			}
		}
	}
}
