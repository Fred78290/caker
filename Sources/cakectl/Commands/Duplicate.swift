import ArgumentParser
import Dispatch
import GRPCLib
import GRPC
import TextTable

struct Duplicate: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Duplicate a VM to a new name")

	@OptionGroup var options: Client.Options

	@Argument(help: "Source VM name")
	var from: String

	@Argument(help: "Duplicated VM name")
	var to: String

	@Option(name: .shortAndLong, help: "Reset mac address")
	var resetMacAddress: Bool = false

	@Flag(help: "Output format")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.duplicate(Caked_DuplicateRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.message
	}
}
