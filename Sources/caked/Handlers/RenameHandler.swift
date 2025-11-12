import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct RenameHandler: CakedCommand {
	let request: Caked_RenameRequest

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.renamed = .with {
					$0.oldName = self.request.oldname
					$0.newName = self.request.newname
					$0.renamed = false
					$0.reason = "\(error)"
				}
			}
		}
	}
	
	mutating func run(on: any EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.renamed = CakedLib.RenameHandler.rename(oldname: self.request.oldname, newname: self.request.newname, runMode: runMode).caked
			}
		}
	}
}
