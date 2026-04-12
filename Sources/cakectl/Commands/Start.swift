import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Start: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: String(localized: "Start an existing VM"))

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	var name: String

	@Option(help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout = 180

	@Flag(help: ArgumentHelp(String(localized: "Output format: text or json")))
	var format: Format = .text

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.start(Caked_StartRequest(command: self), callOptions: callOptions).response.wait().vms.started)
	}
}
