import Foundation

struct FQNHandler: TartdCommand {
  var name: String = ""

  func run() async throws -> String {
    return try Shell.runTart(command: "fqn", arguments: [name])
  }
}
