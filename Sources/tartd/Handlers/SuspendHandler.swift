import Foundation

struct SuspendHandler: TartdCommand {
  var name: String

  func run() async throws {
    try Shell.runTart(command: "suspend", arguments: [name])
  }
}
