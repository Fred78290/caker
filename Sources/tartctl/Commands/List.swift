import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib

fileprivate struct VMInfo: Encodable {
    let Source: String
    let Name: String
    let Disk: Int
    let Size: Int
    let SizeOnDisk: Int
    let Running: Bool
    let State: String
}

struct List: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "List created VMs")

    @Option(help: ArgumentHelp("Only display VMs from the specified source (e.g. --source local, --source oci)."))
    var source: String?

    @Option(help: "Output format: text or json")
    var format: Format = .text

    @Flag(name: [.short, .long], help: ArgumentHelp("Only display VM names."))
    var quiet: Bool = false

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    mutating func run(client: Tartd_ServiceNIOClient, arguments: [String]) async throws -> Tartd_TartReply {
		return try await client.tartCommand(Tartd_TartCommandRequest(command: "list", arguments: arguments)).response.get()
    }
}
