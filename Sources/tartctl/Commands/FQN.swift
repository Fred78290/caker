import ArgumentParser
import Foundation
import GRPCLib

struct FQN: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Get a fully-qualified VM name", shouldDisplay: false)

    @Argument(help: "VM name")
    var name: String

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) async throws -> Tarthelper_TartReply {
		return try await client.tartCommand(Tarthelper_TartCommandRequest(command: "fqn", arguments: arguments)).response.get()
    }
}
