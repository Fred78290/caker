import ArgumentParser
import Dispatch
import GRPCLib
import GRPC
import TextTable

struct Delete: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Delete a VM")

	@OptionGroup var options: Client.Options

	@Flag(help: "Output format")
	var format: Format = .text

	@Argument(help: "VM name")
	var name: [String] = []

	@Flag(name: [.short, .long], help: "Delete all VM")
	var all: Bool = false

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.delete(Caked_DeleteRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.delete)
	}
}
