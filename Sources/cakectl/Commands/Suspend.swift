import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Suspend: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: String(localized: "Suspend VM(s)"))

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Argument(help: ArgumentHelp(String(localized: "VM names to suspend")))
	var names: [String] = []

	@Flag(help: ArgumentHelp(String(localized: "Output format: text or json")))
	var format: Format = .text

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.suspend(Caked_SuspendRequest(command: self), callOptions: callOptions).response.wait().vms.suspend

		if result.success {
			return self.format.render(result.objects)
		} else {
			return self.format.render(result.reason)
		}
	}
}
