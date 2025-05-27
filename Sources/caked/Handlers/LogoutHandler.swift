import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import SystemConfiguration

struct LogoutHandler: CakedCommand {
	let request: Caked_LogoutRequest

	@discardableResult static func logout(host: String, direct: Bool, asSystem: Bool) throws -> String {
		return try Shell.runTart(command: "logout", arguments: [host], direct: direct, asSystem: asSystem)
	}

	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		try Caked_Reply.with {
			$0.tart = try Caked_TartReply.with {
				$0.message = try Self.logout(host: self.request.host, direct: false, asSystem: asSystem)
			}
		}
	}
}
