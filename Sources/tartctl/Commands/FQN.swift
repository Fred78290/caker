import ArgumentParser
import Foundation
import GRPCLib

struct FQN: GrpcAsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Get a fully-qualified VM name", shouldDisplay: false)

  @Argument(help: "VM name")
  var name: String

  mutating func run() async throws {
    throw GrpcError(code: 0, reason: "nothing here")
  }

  mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
    return try await client.fQN(Tartd_FqnRequest(command: self)).response.get()
  }
}
