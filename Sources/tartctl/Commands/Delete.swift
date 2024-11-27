import ArgumentParser
import Dispatch
import GRPCLib

struct Delete: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Delete a VM")

	@Argument(help: "VM name")
	var name: [String]

	func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) throws -> Tarthelper_TartReply {
		return try client.tartCommand(Tarthelper_TartCommandRequest(command: "delete", arguments: arguments)).response.wait()
	}
}
