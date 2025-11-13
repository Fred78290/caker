import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct LoginHandler: CakedCommand {
	let request: Caked_LoginRequest

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		Caked_Reply.with {
			$0.tart = Caked_TartReply.with {
				$0.message = "\(error)"
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.tart = Caked_TartReply.with {
				$0.message = CakedLib.LoginHandler.login(
					host: self.request.host, username: self.request.username, password: self.request.password, insecure: self.request.insecure, noValidate: self.request.insecure, direct: false, runMode: runMode)
			}
		}
	}
}
