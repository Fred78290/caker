import ArgumentParser
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIOCore

struct WaitIPHandler: CakedCommand {
	var name: String
	var wait: Int

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		return try Caked_Reply.with { reply in
			reply.vms = try Caked_VirtualMachineReply.with {
				$0.message = try CakedLib.WaitIPHandler.waitIP(name: name, wait: wait, runMode: runMode)
			}
		}
	}

}
