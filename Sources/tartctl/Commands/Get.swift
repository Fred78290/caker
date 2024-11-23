import ArgumentParser
import Foundation
import GRPCLib

enum Format: String, ExpressibleByArgument {
    case text, json
}

struct Get: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(commandName: "get", abstract: "Get a VM's configuration")

    @Argument(help: "VM name.")
    var name: String

    @Option(help: "Output format: text or json")
    var format: Format = .text

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    mutating func run(client: Tartd_ServiceNIOClient, arguments: [String]) async throws -> Tartd_TartReply {
		return try await client.tartCommand(Tartd_TartCommandRequest(command: "get", arguments: arguments)).response.get()
    }
}
