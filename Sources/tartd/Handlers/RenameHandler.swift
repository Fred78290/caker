import Foundation

struct RenameHandler: TartdCommand {
	var name: String
	var newName: String

	func run() async throws -> String {
		return try Shell.runTart(command: "rename", arguments: [name, newName])
	}
}
