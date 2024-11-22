import Foundation

struct ExportHandler: TartdCommand {
  var name: String
  var path: String?

  func run() async throws -> String {
    var arguments: [String] = []

    arguments.append(name)

    if let path = self.path {
      arguments.append(path)
    }

    return try Shell.runTart(command: "export", arguments: arguments)
  }
}
