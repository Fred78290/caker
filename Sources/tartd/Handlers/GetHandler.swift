import Foundation

struct GetHandler: TartdCommand {
  var name: String
  var format: Format = .text

  func run() async throws {
    var arguments: [String] = []

    arguments.append(name)

    if format != .text {
      arguments.append("--format=\(format.rawValue)")
    }

    try Shell.runTart(command: "get", arguments: arguments)
  }
}
