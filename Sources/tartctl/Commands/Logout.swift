import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib

struct Logout: GrpcAsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Logout from a registry")

  @Argument(help: "host")
  var host: String

  mutating func run() async throws {
    throw GrpcError(code: 0, reason: "nothing here")
  }

  mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
    return try await client.logout(Tartd_LogoutRequest(command: self)).response.get()
  }
}
