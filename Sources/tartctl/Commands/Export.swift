import ArgumentParser
import Foundation
import GRPCLib

struct Export: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Export VM to a compressed .tvm file")

    @Argument(help: "Source VM name.")
    var name: String

    @Argument(help: "Path to the destination file.")
    var path: String?

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
        return try await client.exportVM(Tartd_ExportRequest(command: self)).response.get()
    }
}
