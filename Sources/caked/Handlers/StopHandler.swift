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
				$0.success = false
				$0.reason = "\(error)"
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.stop = CakedLib.StopHandler.stopVMs(all: self.request.all, names: self.request.names.list, force: self.request.force, runMode: runMode).caked
			}
		}
	}
}
