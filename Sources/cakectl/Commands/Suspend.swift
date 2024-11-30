import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Suspend: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "suspend", abstract: "Suspend a VM")

	@Argument(help: "VM name")
	var name: String

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "suspend", arguments: arguments), callOptions: callOptions).response.wait()
	}
}
