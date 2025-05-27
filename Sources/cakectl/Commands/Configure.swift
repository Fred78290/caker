import ArgumentParser
import GRPC
import GRPCLib
import Virtualization

struct Configure: AsyncParsableCommand {
	static let configuration = ConfigureOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Configure VM options")
	var configure: ConfigureOptions

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.configure(Caked_ConfigureRequest(options: self.configure), callOptions: callOptions).response.wait().successfull().vms.message
	}

}
