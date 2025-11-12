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

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.delete = .with {
					$0.deleted = false
					$0.reason = "\(error)"
				}
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		try Caked_Reply.with { reply in
			reply.vms = try Caked_VirtualMachineReply.with {
				$0.delete = try Caked_DeleteReply.with {
					$0.deleted = true
					$0.objects = try CakedLib.DeleteHandler.delete(all: self.request.all, names: self.request.names.list, runMode: runMode).map {
						$0.toCaked_DeletedObject()
					}
				}
			}
		}
	}
}
