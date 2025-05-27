import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import TextTable

struct Duplicate: GrpcParsableCommand {
	static let configuration = DuplicateOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Duplicate options")
	var duplicate: DuplicateOptions

	@Flag(help: "Output format")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.duplicate(Caked_DuplicateRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.message
	}
}
