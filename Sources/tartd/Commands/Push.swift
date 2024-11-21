import Foundation

struct Push: TartdCommand {
  var localName: String
  var remoteNames: [String]
  var insecure: Bool = false
  var concurrency: UInt = 4
  var chunkSize: Int = 0
  var diskFormat: String = "v2"
  var populateCache: Bool = false

  func run() async throws {
    var arguments: [String] = []

    arguments.append(localName)
	arguments.append(remoteNames)

    if insecure {
      arguments.append("--insecure")
    }

    if chunkSize != 4 {
      arguments.append("--chunk-size=\(chunkSize)")
    }

    if concurrency != 4 {
      arguments.append("--concurrency=\(concurrency)")
    }

    try Shell.runTart(command: "push", arguments: arguments)
  }
}
