import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib

struct Logout: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Logout from a registry")

    @Argument(help: "host")
    var host: String

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) async throws -> Tarthelper_TartReply {
		return try await client.tartCommand(Tarthelper_TartCommandRequest(command: "logout", arguments: arguments)).response.get()
    }
}
