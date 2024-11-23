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

    mutating func run(client: Tartd_ServiceNIOClient, arguments: [String]) async throws -> Tartd_TartReply {
        return try await client.start(Tartd_StartRequest(command: self)).response.get()
    }
}
