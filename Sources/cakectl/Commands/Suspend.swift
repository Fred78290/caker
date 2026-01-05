import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Suspend: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Suspend VM(s)")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Argument(help: "VM names to suspend")
	var names: [String] = []

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.suspend(Caked_SuspendRequest(command: self), callOptions: callOptions).response.wait().vms.suspend

		if result.success {
			return self.format.render(result.objects)
		} else {
			return self.format.render(result.reason)
		}
	}
}
