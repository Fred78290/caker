import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct LogoutHandler: CakedCommand {
	let request: Caked_LogoutRequest

	func replyError(error: any Error) -> Caked_Reply {
		Caked_Reply.with {
			$0.oci = Caked_OCIReply.with {
				$0.logout = Caked_LogoutReply.with {
					$0.success = false
					$0.message = "\(error)"
				}
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		Caked_Reply.with {
			$0.oci = Caked_OCIReply.with {
				$0.logout = CakedLib.LogoutHandler.logout(host: self.request.host, direct: false, runMode: runMode).caked
			}
		}
	}
}
