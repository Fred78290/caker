import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import SystemConfiguration

struct LogoutHandler: CakedCommand {
	let request: Caked_LogoutRequest

	@discardableResult static func logout(host: String, direct: Bool, runMode: Utils.RunMode) throws -> String {
		return try Shell.runTart(command: "logout", arguments: [host], direct: direct, runMode: runMode)
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		try Caked_Reply.with {
			$0.tart = try Caked_TartReply.with {
				$0.message = try Self.logout(host: self.request.host, direct: false, runMode: runMode)
			}
		}
	}
}
