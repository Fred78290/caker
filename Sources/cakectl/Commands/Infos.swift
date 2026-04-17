import ArgumentParser
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import TextTable

struct Infos: GrpcParsableCommand {
	static let configuration = CommandConfiguration(commandName: "infos", abstract: String(localized: "Get info for VM"))

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	var name: String

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.info(Caked_InfoRequest(command: self), callOptions: callOptions).response.wait().vms.status

		if result.success {
			return self.options.format.render(result.infos)
		} else {
			return self.options.format.render(result.reason)
		}
	}
}
