import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct LoginHandler: CakedCommand {
	let request: Caked_LoginRequest

	func replyError(error: any Error) -> Caked_Reply {
		Caked_Reply.with {
			$0.oci = Caked_OCIReply.with {
				$0.login = Caked_LoginReply.with {
					$0.success = false
					$0.message = "\(error)"
				}
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		let result = on.makeFutureWithTask {
			return await CakedLib.LoginHandler.login(
				host: self.request.host, username: self.request.username, password: self.request.password, insecure: self.request.insecure, noValidate: self.request.insecure, direct: false, runMode: runMode)
		}

		do {
			return try Caked_Reply.with {
				$0.oci = try Caked_OCIReply.with {
					$0.login = try result.wait().caked
				}
			}
		} catch {
			return Caked_Reply.with {
				$0.oci = Caked_OCIReply.with {
					$0.login = Caked_LoginReply.with {
						$0.success = false
						$0.message = "\(error)"
					}
				}
			}
		}
	}
}
