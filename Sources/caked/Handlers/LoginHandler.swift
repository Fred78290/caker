import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import CakedLib

struct LoginHandler: CakedCommand {
	let request: Caked_LoginRequest

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		try Caked_Reply.with {
			$0.tart = try Caked_TartReply.with {
				$0.message = try CakedLib.LoginHandler.login(host: self.request.host, username: self.request.username, password: self.request.password, insecure: self.request.insecure, noValidate: self.request.insecure, direct: false, runMode: runMode)
			}
		}
	}
}
