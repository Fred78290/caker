import ArgumentParser
import Foundation
import GRPCLib

struct Stop: GrpcAsyncParsableCommand {
  static var configuration = CommandConfiguration(commandName: "stop", abstract: "Stop a VM")

  @Argument(help: "VM name")
  var name: String

  @Option(name: [.short, .long], help: "Seconds to wait for graceful termination before forcefully terminating the VM")
  var timeout: UInt64 = 30

  mutating func run() async throws {
    throw GrpcError(code: 0, reason: "nothing here")
  }

  mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
    return try await client.stop(Tartd_StopRequest(command: self)).response.get()
  }
}
