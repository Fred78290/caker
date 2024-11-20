import Foundation

struct Stop: TartdCommand {
  var name: String
  var timeout: UInt64 = 30

  func run() async throws {
    var arguments: [String] = []

    arguments.append(name)

    if timeout != 30 {
      arguments.append("--timeout=\(timeout)")
    }

    try Shell.runTart(command: "push", arguments: arguments)
  }
}
