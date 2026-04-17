import ArgumentParser
import GRPC
import GRPCLib
import Virtualization
import CakeAgentLib

struct Configure: AsyncParsableCommand {
	static let configuration = ConfigureOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Configure VM options"))
	var configure: ConfigureOptions

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.options.format.render(try client.configure(Caked_ConfigureRequest(options: self.configure), callOptions: callOptions).response.wait().vms.configured)
	}

}
