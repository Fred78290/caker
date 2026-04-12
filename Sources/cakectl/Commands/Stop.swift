import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Stop: GrpcParsableCommand {
	static let configuration = StopOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Global options"))
	var stop: StopOptions

	@Flag(help: ArgumentHelp(String(localized: "Output format: text or json")))
	var format: Format = .text

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.stop(Caked_StopRequest(command: self), callOptions: callOptions).response.wait().vms.stop

		if result.success {
			return self.format.render(result.objects)
		} else {
			return self.format.render(result.reason)
		}
	}
}
