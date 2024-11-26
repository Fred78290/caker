import ArgumentParser
import Foundation
import GRPCLib

struct Suspend: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(commandName: "suspend", abstract: "Suspend a VM")

    @Argument(help: "VM name")
    var name: String

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) async throws -> Tarthelper_TartReply {
		return try await client.tartCommand(Tarthelper_TartCommandRequest(command: "suspend", arguments: arguments)).response.get()
    }
}
