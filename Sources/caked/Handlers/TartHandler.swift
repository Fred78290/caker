import Foundation
import NIOCore
import GRPCLib

struct TartHandler: CakedCommand {
	var command: String
	var arguments: [String]

	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		try Caked_Reply.with {
			$0.tart = try Caked_TartReply.with {
				$0.message = try Shell.runTart(command: self.command, arguments: self.arguments)
			}
		}
	}
}
