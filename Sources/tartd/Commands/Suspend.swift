import Foundation

struct Suspend: TartdCommand {
  var name: String

  func run() async throws {
    try Shell.runTart(command: "suspend", arguments: [name])
  }
}
