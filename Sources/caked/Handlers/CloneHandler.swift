import ArgumentParser
import Foundation
import GRPCLib
import Logging
import NIO
import CakedLib


struct CloneHandler: CakedCommand {
	var request: Caked_CloneRequest

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		return try Caked_Reply.with { reply in
			reply.vms = try Caked_VirtualMachineReply.with {
				$0.message = try CakedLib.CloneHandler.clone(
					name: self.request.targetName, from: self.request.sourceName, concurrency: UInt(self.request.concurrency), deduplicate: self.request.deduplicate, insecure: self.request.insecure, direct: false, runMode: runMode)
			}
		}
	}
}
