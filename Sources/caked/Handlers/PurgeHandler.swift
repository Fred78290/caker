import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct PurgeHandler: CakedCommand {
	var options: PurgeOptions

	func replyError(error: any Error) -> Caked_Reply {
		Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.purged = .with {
					$0.purged = false
					$0.reason = "\(error)"
				}
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.purged = CakedLib.PurgeHandler.purge(direct: runMode.isSystem, runMode: runMode, options: self.options).caked
			}
		}
	}
}
