import Foundation

struct FQNHandler: TartdCommand {
  var name: String = ""

  func run() async throws {
    try Shell.runTart(command: "fqn", arguments: [name])
  }
}
