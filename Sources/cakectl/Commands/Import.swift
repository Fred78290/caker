import ArgumentParser
import Foundation
import GRPCLib

struct Import: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Import VM from a compressed .tvm file")

	@Argument(help: "Path to a file created with \"tart export\".")
	var path: String

	@Argument(help: "Destination VM name.")
	var name: String

	func run(client: Caked_ServiceNIOClient, arguments: [String]) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "import", arguments: arguments)).response.wait()
	}
}
