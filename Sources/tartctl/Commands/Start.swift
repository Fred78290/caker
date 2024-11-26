import ArgumentParser
import Foundation
import GRPCLib

struct Start: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Launch a linux VM create in background")

    @Argument(help: "VM name")
    var name: String

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) async throws -> Tarthelper_TartReply {
        return try await client.start(Tarthelper_StartRequest(command: self)).response.get()
    }
}
