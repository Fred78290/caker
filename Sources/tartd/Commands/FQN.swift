import Foundation

struct FQN: TartdCommand {
  var name: String

  func run() async throws {
    try Shell.runTart(command: "fqn", arguments: [name])
  }
}
