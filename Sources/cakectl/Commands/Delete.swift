import ArgumentParser
import Dispatch
import GRPCLib
import GRPC

struct Delete: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Delete a VM")

	@Argument(help: "VM name")
	var name: [String]

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "delete", arguments: arguments), callOptions: callOptions).response.wait()
	}
}
