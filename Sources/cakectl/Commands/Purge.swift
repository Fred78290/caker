import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Purge: GrpcParsableCommand {
	static let configuration = PurgeOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Purge options"))
	var purge: PurgeOptions

	@Flag(help: ArgumentHelp(String(localized: "Output format: text or json")))
	var format: Format = .text

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.purge(Caked_PurgeRequest(command: self), callOptions: callOptions).response.wait().vms.purged)
	}
}
