import ArgumentParser
import Foundation
import GRPCLib

struct Import: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Import VM from a compressed .tvm file")

	@Argument(help: "Path to a file created with \"tart export\".")
	var path: String

	@Argument(help: "Destination VM name.")
	var name: String

	func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) throws -> Tarthelper_TartReply {
		return try client.tartCommand(Tarthelper_TartCommandRequest(command: "import", arguments: arguments)).response.wait()
	}
}
