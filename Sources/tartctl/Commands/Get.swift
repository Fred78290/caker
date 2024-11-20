import ArgumentParser
import Foundation

enum Format: String, ExpressibleByArgument {
  case text, json
}

struct Get: GrpcAsyncParsableCommand {
  static var configuration = CommandConfiguration(commandName: "get", abstract: "Get a VM's configuration")

  @Argument(help: "VM name.")
  var name: String

  @Option(help: "Output format: text or json")
  var format: Format = .text

  mutating func run() async throws {
    throw GrpcError(code: 0, reason: "nothing here")
  }

  mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
    return try await client.get(Tartd_GetRequest(command: self)).response.get()
  }
}
