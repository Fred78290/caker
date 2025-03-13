import ArgumentParser
import Virtualization
import GRPCLib
import GRPC

struct Configure: AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Reconfigure VM")

	@OptionGroup var options: Client.Options
	@OptionGroup var configure: ConfigureOptions
	
	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.configure(Caked_ConfigureRequest(options: self.configure), callOptions: callOptions).response.wait()
	}

}
