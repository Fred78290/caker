import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import Logging
import NIO

struct CloneHandler: CakedCommand {
	var request: Caked_CloneRequest

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.cloned = CakedLib.CloneHandler.clone(
					name: self.request.targetName, from: self.request.sourceName, concurrency: UInt(self.request.concurrency), deduplicate: self.request.deduplicate, insecure: self.request.insecure, direct: false, runMode: runMode).caked
			}
		}
	}
}
