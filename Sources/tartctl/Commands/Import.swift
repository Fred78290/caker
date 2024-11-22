import ArgumentParser
import Foundation
import GRPCLib

struct Import: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Import VM from a compressed .tvm file")

    @Argument(help: "Path to a file created with \"tart export\".")
    var path: String

    @Argument(help: "Destination VM name.")
    var name: String

    func validate() throws {
        if name.contains("/") {
            throw ValidationError("<name> should be a local name")
        }
    }

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
        return try await client.importVM(Tartd_ImportRequest(command: self)).response.get()
    }
}
