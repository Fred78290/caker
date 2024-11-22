import Foundation

struct SuspendHandler: TartdCommand {
	var name: String

	func run() async throws -> String {
		return try Shell.runTart(command: "suspend", arguments: [name])
	}
}
