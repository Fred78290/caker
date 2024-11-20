import Foundation

struct Rename: TartdCommand {
  var name: String
  var newName: String

  func run() async throws {
    try Shell.runTart(command: "rename", arguments: [name, newName])
  }
}
