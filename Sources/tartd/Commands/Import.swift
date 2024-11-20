import Foundation

struct Import: TartdCommand {
  var path: String
  var name: String

  func run() async throws {
    try Shell.runTart(command: "import", arguments: [name])
  }
}
