import CakedLib
//
//  DeleteHandler..swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/02/2025.
//
import Foundation
import GRPCLib
import NIO

struct DeleteHandler: CakedCommand {
	var request: Caked_DeleteRequest

	func replyError(error: any Error) -> Caked_Reply {
		Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.delete = .with {
					$0.success = false
					$0.reason = "\(error)"
				}
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.delete = CakedLib.DeleteHandler.delete(all: self.request.all, names: self.request.names.list, runMode: runMode).caked
			}
		}
	}
}
