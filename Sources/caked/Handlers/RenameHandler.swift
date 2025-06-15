import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import CakedLib


struct RenameHandler: CakedCommand {
	let request: Caked_RenameRequest

	mutating func run(on: any EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		let oldname = self.request.oldname
		let newname = self.request.newname

		return try Caked_Reply.with {
			$0.vms = try Caked_VirtualMachineReply.with {
				$0.message = try CakedLib.RenameHandler.rename(oldname: oldname, newname: newname, runMode: runMode)
			}
		}
	}
}
