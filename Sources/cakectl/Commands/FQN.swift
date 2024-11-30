import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct FQN: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Get a fully-qualified VM name", shouldDisplay: false)

	@Argument(help: "VM name")
	var name: String

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "fqn", arguments: arguments), callOptions: callOptions).response.wait()
	}
}
