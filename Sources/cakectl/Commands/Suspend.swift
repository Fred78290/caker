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

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.suspend(Caked_SuspendRequest(command: self), callOptions: callOptions).response.wait().vms.suspend

		if result.success {
			return self.options.format.render(result.objects)
		} else {
			return self.options.format.render(result.reason)
		}
	}
}
