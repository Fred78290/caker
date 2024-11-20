import ArgumentParser
import Dispatch
import GRPCLib

struct Delete: GrpcAsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Delete a VM")

  @Argument(help: "VM name")
  var name: [String]

  mutating func run() async throws {
    throw GrpcError(code: 0, reason: "nothing here")
  }

  mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
    return try await client.delete(Tartd_DeleteRequest(command: self)).response.get()
  }
}
