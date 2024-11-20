import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib

struct Pull: GrpcAsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Pull a VM from a registry",
    discussion: """
    Pulls a virtual machine from a remote OCI-compatible registry. Supports authorization via Keychain (see "tart login --help"),
    Docker credential helpers defined in ~/.docker/config.json or via TART_REGISTRY_USERNAME/TART_REGISTRY_PASSWORD environment variables.

    By default, Tart checks available capacity in Tart's home directory and tries to reclaim minimum possible storage for the remote image
    to fit. This behaviour is called "automatic pruning" and can be disabled by setting TART_NO_AUTO_PRUNE environment variable.
    """
  )

  @Argument(help: "remote VM name")
  var remoteName: String

  @Flag(help: "connect to the OCI registry via insecure HTTP protocol")
  var insecure: Bool = false

  @Option(help: "network concurrency to use when pulling a remote VM from the OCI-compatible registry")
  var concurrency: UInt = 4

  @Flag(help: .hidden)
  var deduplicate: Bool = false

  func validate() throws {
    if concurrency < 1 {
      throw ValidationError("network concurrency cannot be less than 1")
    }
  }

  mutating func run() async throws {
    throw GrpcError(code: 0, reason: "nothing here")
  }

  mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
    return try await client.pull(Tartd_PullRequest(command: self)).response.get()
  }
}
