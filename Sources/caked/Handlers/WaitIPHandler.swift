import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import SystemConfiguration

struct WaitIPHandler: CakedCommand {
	var name: String
	var wait: Int

	static func waitIP(name: String, wait: Int, runMode: Utils.RunMode, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let vmLocation = try StorageLocation(runMode: runMode).find(name)

		return try vmLocation.waitIP(wait: wait, runMode: runMode, startedProcess: startedProcess)
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		return try Caked_Reply.with { reply in
			reply.vms = try Caked_VirtualMachineReply.with {
				$0.message = try Self.waitIP(name: name, wait: wait, runMode: runMode)
			}
		}
	}

}
