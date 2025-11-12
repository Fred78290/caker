import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Clone: GrpcParsableCommand {
	static let configuration = CloneOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Clone options")
	var clone: CloneOptions

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.clone(Caked_CloneRequest(command: self), callOptions: callOptions).response.wait().vms.cloned)
	}
}
