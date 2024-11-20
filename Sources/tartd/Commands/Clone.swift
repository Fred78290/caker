import Foundation
import SystemConfiguration

struct Clone: TartdCommand {
  var sourceName: String
  var newName: String
  var insecure: Bool = false
  var concurrency: UInt = 4
  var deduplicate: Bool = false

  func run() async throws {
    var arguments: [String] = []

    arguments.append(sourceName)
    arguments.append(newName)

    if insecure {
      arguments.append("--insecure")
    }

    if deduplicate {
      arguments.append("--deduplicate")
    }

    if concurrency != 4 {
      arguments.append("--concurrency=\(concurrency)")
    }

    try Shell.runTart(command: "clone", arguments: arguments)
  }
}
