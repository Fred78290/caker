import ArgumentParser
import Dispatch
import GRPCLib
import GRPC
import TextTable

struct Delete: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Delete a VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: [String]

	@Option(name: .shortAndLong, help: "Output format")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.delete(Caked_DeleteRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.delete)
	}
}
