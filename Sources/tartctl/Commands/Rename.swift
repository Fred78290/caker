import ArgumentParser
import Foundation
import GRPCLib

struct Rename: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Rename a local VM")

    @Argument(help: "VM name")
    var name: String

    @Argument(help: "new VM name")
    var newName: String

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    mutating func run(client: Tartd_ServiceNIOClient, arguments: [String]) async throws -> Tartd_TartReply {
		return try await client.tartCommand(Tartd_TartCommandRequest(command: "rename", arguments: arguments)).response.get()
    }
}
