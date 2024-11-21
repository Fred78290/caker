import Foundation

struct ListHandler: TartdCommand {
  var source: String?
  var format: Format = .text
  var quiet: Bool = false

  func run() async throws {
    var arguments: [String] = []

    if let source = self.source {
      arguments.append(source)
    }

    if quiet {
      arguments.append("--quiet")
    }

    if format != .text {
      arguments.append("--format=\(format.rawValue)")
    }

    try Shell.runTart(command: "list", arguments: arguments)
  }
}
