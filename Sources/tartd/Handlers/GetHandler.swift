import Foundation

struct GetHandler: TartdCommand {
	var name: String
	var format: Format = .text

	func run() async throws -> String {
		var arguments: [String] = []

		arguments.append(name)

		if format != .text {
			arguments.append("--format=\(format.rawValue)")
		}

		return try Shell.runTart(command: "get", arguments: arguments)
	}
}
