import Foundation

struct TartHandler: TartdCommand {
	var command: String
	var arguments: [String]

  func run() async throws -> String {
    return try Shell.runTart(command: self.command, arguments: self.arguments)
  }
}