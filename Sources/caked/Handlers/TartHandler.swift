import Foundation
import GRPCLib
import NIOCore

struct TartHandler: CakedCommand {
	var command: String
	var arguments: [String]

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		try Caked_Reply.with {
			$0.tart = try Caked_TartReply.with {
				$0.message = try Shell.runTart(command: self.command, arguments: self.arguments, runMode: runMode)
			}
		}
	}
}
