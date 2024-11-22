import Foundation

struct StopHandler: TartdCommand {
  var name: String
  var timeout: UInt64 = 30

  func run() async throws -> String {
    var arguments: [String] = []

    arguments.append(name)

    if timeout != 30 {
      arguments.append("--timeout=\(timeout)")
    }

    return try Shell.runTart(command: "push", arguments: arguments)
  }
}
