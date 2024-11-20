import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib

struct Login: GrpcAsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Login to a registry")

  @Argument(help: "host")
  var host: String

  @Option(help: "username")
  var username: String?

  @Flag(help: "password-stdin")
  var passwordStdin: Bool = false

  @Flag(help: "connect to the OCI registry via insecure HTTP protocol")
  var insecure: Bool = false

  @Flag(help: "skip validation of the registry's credentials before logging-in")
  var noValidate: Bool = false

  func validate() throws {
    let usernameProvided = username != nil
    let passwordProvided = passwordStdin

    if usernameProvided != passwordProvided {
      throw ValidationError("both --username and --password-stdin are required")
    }
  }

  mutating func run() async throws {
    throw GrpcError(code: 0, reason: "nothing here")
  }

  mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
    return try await client.login(Tartd_LoginRequest(command: self)).response.get()
  }
}
