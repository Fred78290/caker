import Foundation

struct Export: TartdCommand {
  var name: String
  var path: String?

  func run() async throws {
    var arguments: [String] = []

    arguments.append(name)

    if let path = self.path {
      arguments.append(path)
    }

    try Shell.runTart(command: "export", arguments: arguments)
  }
}
