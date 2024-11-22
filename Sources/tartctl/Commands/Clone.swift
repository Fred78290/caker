import ArgumentParser
import Foundation
import GRPCLib

struct Clone: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Clone a VM",
        discussion: """
        Creates a local virtual machine by cloning either a remote or another local virtual machine.

        Due to copy-on-write magic in Apple File System, a cloned VM won't actually claim all the space right away.
        Only changes to a cloned disk will be written and claim new space. This also speeds up clones enormously.

        By default, Tart checks available capacity in Tart's home directory and tries to reclaim minimum possible storage for the cloned image
        to fit. This behaviour is called "automatic pruning" and can be disabled by setting TART_NO_AUTO_PRUNE environment variable.
        """
    )

    @Argument(help: "source VM name")
    var sourceName: String

    @Argument(help: "new VM name")
    var newName: String

    @Flag(help: "connect to the OCI registry via insecure HTTP protocol")
    var insecure: Bool = false

    @Option(help: "network concurrency to use when pulling a remote VM from the OCI-compatible registry")
    var concurrency: UInt = 4

    @Flag(help: .hidden)
    var deduplicate: Bool = false

    func validate() throws {
        if newName.contains("/") {
            throw ValidationError("<new-name> should be a local name")
        }

        if concurrency < 1 {
            throw ValidationError("network concurrency cannot be less than 1")
        }
    }

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
        return try await client.clone(Tartd_CloneRequest(command: self)).response.get()
    }
}
