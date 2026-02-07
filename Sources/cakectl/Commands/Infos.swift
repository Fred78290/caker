import ArgumentParser
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import TextTable

struct Infos: GrpcParsableCommand {
	static let configuration = CommandConfiguration(commandName: "infos", abstract: "Get info for VM")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	@Argument(help: "VM name")
	var name: String

	func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.info(Caked_InfoRequest(command: self), callOptions: callOptions).response.wait().vms.status

		if result.success {
			return self.format.render(result.status)
		} else {
			return self.format.render(result.reason)
		}
	}
}
