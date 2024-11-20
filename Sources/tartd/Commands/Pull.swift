import Foundation

struct Pull: TartdCommand {
  var remoteName: String
  var insecure: Bool = false
  var concurrency: UInt = 4
  var deduplicate: Bool = false

  func run() async throws {
    var arguments: [String] = []

    arguments.append(remoteName)

    if insecure {
      arguments.append("--insecure")
    }

    if deduplicate {
      arguments.append("--deduplicate")
    }

    if concurrency != 4 {
      arguments.append("--concurrency=\(concurrency)")
    }

    try Shell.runTart(command: "pull", arguments: arguments)
  }
}
