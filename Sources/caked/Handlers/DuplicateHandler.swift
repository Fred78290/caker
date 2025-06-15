import Foundation
import GRPCLib
import NIOCore
import CakedLib


struct DuplicateHandler: CakedCommand {
	var request: Caked_DuplicateRequest

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		return try Caked_Reply.with {
			$0.vms = try Caked_VirtualMachineReply.with {
				$0.message = try CakedLib.DuplicateHandler.duplicate(from: self.request.from, to: self.request.to, resetMacAddress: self.request.resetMacAddress, runMode: runMode)
			}
		}
	}
}
