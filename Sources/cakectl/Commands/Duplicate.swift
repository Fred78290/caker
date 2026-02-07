import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import TextTable
import CakeAgentLib

struct Duplicate: GrpcParsableCommand {
	static let configuration = DuplicateOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Duplicate options")
	var duplicate: DuplicateOptions

	@Flag(help: "Output format")
	var format: Format = .text

	func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.duplicate(Caked_DuplicateRequest(command: self), callOptions: callOptions).response.wait().vms.duplicated)
	}
}
