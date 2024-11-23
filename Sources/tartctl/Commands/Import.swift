import ArgumentParser
import Foundation
import GRPCLib

struct Import: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Import VM from a compressed .tvm file")

    @Argument(help: "Path to a file created with \"tart export\".")
    var path: String

    @Argument(help: "Destination VM name.")
    var name: String

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    mutating func run(client: Tartd_ServiceNIOClient, arguments: [String]) async throws -> Tartd_TartReply {
		return try await client.tartCommand(Tartd_TartCommandRequest(command: "import", arguments: arguments)).response.get()
    }
}
