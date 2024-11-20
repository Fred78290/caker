import ArgumentParser
import Foundation
import GRPCLib

struct Rename: GrpcAsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Rename a local VM")

  @Argument(help: "VM name")
  var name: String

  @Argument(help: "new VM name")
  var newName: String

  func validate() throws {
    if newName.contains("/") {
      throw ValidationError("<new-name> should be a local name")
    }
  }

  mutating func run() async throws {
    throw GrpcError(code: 0, reason: "nothing here")
  }

  mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
    return try await client.rename(Tartd_RenameRequest(command: self)).response.get()
  }
}
