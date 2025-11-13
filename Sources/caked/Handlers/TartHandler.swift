import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct TartHandler: CakedCommand {
	var command: String
	var arguments: [String]

	func replyError(error: any Error) -> Caked_Reply {
		Caked_Reply.with {
			$0.tart = Caked_TartReply.with {
				$0.message = "\(error)"
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		let message: String

		do {
			message = try Shell.runTart(command: self.command, arguments: self.arguments, runMode: runMode)
		} catch {
			message = "\(error)"
		}

		return Caked_Reply.with {
			$0.tart =  Caked_TartReply.with {
				$0.message = message
			}
		}
	}
}
