import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import TextTable

struct Delete: GrpcParsableCommand {
	static let configuration: CommandConfiguration = DeleteOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Delete options")
	var delete: DeleteOptions

	@Flag(help: "Output format")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.delete(Caked_DeleteRequest(command: self), callOptions: callOptions).response.wait().vms.delete)
	}
}
