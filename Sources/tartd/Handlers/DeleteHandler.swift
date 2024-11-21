import Foundation

struct DeleteHandler: TartdCommand {
  var name: [String] = []

  func run() async throws {
    try Shell.runTart(command: "delete", arguments: name)
  }
}
