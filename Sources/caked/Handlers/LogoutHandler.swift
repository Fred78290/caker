import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct LogoutHandler: CakedCommand {
	let request: Caked_LogoutRequest

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		try Caked_Reply.with {
			$0.tart = try Caked_TartReply.with {
				$0.message = try CakedLib.LogoutHandler.logout(host: self.request.host, direct: false, runMode: runMode)
			}
		}
	}
}
