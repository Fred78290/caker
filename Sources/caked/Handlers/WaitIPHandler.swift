import ArgumentParser
import Foundation
import SystemConfiguration
import GRPC
import GRPCLib
import NIOCore
import NIOPosix

struct WaitIPHandler: CakedCommand {
	var name: String
	var wait: Int

	static func waitIP(name: String, wait: Int, asSystem: Bool, startedProcess: ProcessWithSharedFileHandle? = nil) throws -> String {
		let vmLocation = try StorageLocation(asSystem: asSystem).find(name)

		return try vmLocation.waitIP(wait: wait, asSystem: asSystem, startedProcess: startedProcess)
	}

	func run(on: EventLoop, asSystem: Bool) throws -> String {
		try Self.waitIP(name: name, wait: wait, asSystem: asSystem)
	}

}
