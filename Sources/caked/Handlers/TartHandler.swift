import Foundation
import NIOCore

struct TartHandler: CakedCommand {
	var command: String
	var arguments: [String]

	func run(on: EventLoop, asSystem: Bool) throws -> String {
		return try Shell.runTart(command: self.command, arguments: self.arguments)
	}
}
