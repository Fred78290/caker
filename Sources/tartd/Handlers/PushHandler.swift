import Foundation

struct PushHandler: TartdCommand {
  var localName: String
  var remoteNames: [String]
  var insecure: Bool = false
  var concurrency: UInt = 4
  var chunkSize: Int = 0
  var diskFormat: String = "v2"
  var populateCache: Bool = false

  func run() async throws -> String {
    var arguments: [String] = []

    arguments.append(localName)
    arguments += remoteNames

    if insecure {
      arguments.append("--insecure")
    }

    if chunkSize != 4 {
      arguments.append("--chunk-size=\(chunkSize)")
    }

    if concurrency != 4 {
      arguments.append("--concurrency=\(concurrency)")
    }

    return try Shell.runTart(command: "push", arguments: arguments)
  }
}
