import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Suspend: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Suspend VM(s)")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Argument(help: "VM names to suspend")
	var names: [String] = []

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.suspend(Caked_SuspendRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.suspend)
	}
}
