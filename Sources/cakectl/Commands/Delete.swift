import ArgumentParser
import Dispatch
import GRPCLib
import GRPC

struct Delete: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Delete a VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: [String]

	@Option(name: .shortAndLong, help: "Output format")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.delete(Caked_DeleteRequest(command: self), callOptions: callOptions).response.wait()
	}
}
