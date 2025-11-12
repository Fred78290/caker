import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Purge: GrpcParsableCommand {
	static let configuration = PurgeOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Purge options")
	var purge: PurgeOptions

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.purge(Caked_PurgeRequest(command: self), callOptions: callOptions).response.wait().vms.purged)
	}
}
