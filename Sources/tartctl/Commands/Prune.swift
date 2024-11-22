import ArgumentParser
import Foundation
import GRPCLib

struct Prune: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Prune OCI and IPSW caches or local VMs")

    @Option(help: ArgumentHelp("Entries to remove: \"caches\" targets OCI and IPSW caches and \"vms\" targets local VMs."))
    var entries: String = "caches"

    @Option(help: ArgumentHelp("Remove entries that were last accessed more than n days ago",
                               discussion: "For example, --older-than=7 will remove entries that weren't accessed by Tart in the last 7 days.",
                               valueName: "n"))
    var olderThan: UInt?

    @Option(help: .hidden)
    var cacheBudget: UInt?

    @Option(help: ArgumentHelp("Remove the least recently used entries that do not fit the specified space size budget n, expressed in gigabytes",
                               discussion: "For example, --space-budget=50 will effectively shrink all entries to a total size of 50 gigabytes.",
                               valueName: "n"))
    var spaceBudget: UInt?

    @Flag(help: .hidden)
    var gc: Bool = false

    mutating func validate() throws {
        // --cache-budget deprecation logic
        if let cacheBudget = cacheBudget {
            fputs("--cache-budget is deprecated, please use --space-budget\n", stderr)

            if spaceBudget != nil {
                throw ValidationError("--cache-budget is deprecated, please use --space-budget")
            }

            spaceBudget = cacheBudget
        }

        if olderThan == nil && spaceBudget == nil && !gc {
            throw ValidationError("at least one pruning criteria must be specified")
        }
    }

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
        return try await client.prune(Tartd_PruneRequest(command: self)).response.get()
    }

}
