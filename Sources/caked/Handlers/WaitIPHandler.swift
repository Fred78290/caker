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

	static func waitIP(name: String, wait: Int, asSystem: Bool, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)

		return try vmLocation.waitIP(wait: wait, asSystem: asSystem, startedProcess: startedProcess)
	}

	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		return try Caked_Reply.with { reply in
			reply.vms = try Caked_VirtualMachineReply.with {
				$0.message = try Self.waitIP(name: name, wait: wait, asSystem: asSystem)
			}
		}
	}

}
