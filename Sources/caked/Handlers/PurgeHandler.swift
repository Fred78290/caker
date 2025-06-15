import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import CakedLib


struct PurgeHandler: CakedCommand {
	var options: PurgeOptions

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		try Caked_Reply.with {
			$0.vms = try Caked_VirtualMachineReply.with {
				$0.message = try CakedLib.PurgeHandler.purge(direct: runMode.isSystem, runMode: runMode, options: self.options)
			}
		}
	}
}
