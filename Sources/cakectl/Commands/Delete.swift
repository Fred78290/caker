import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import TextTable
import CakeAgentLib

struct Delete: GrpcParsableCommand {
	static let configuration: CommandConfiguration = DeleteOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Delete options")
	var delete: DeleteOptions

	@Flag(help: "Output format")
	var format: Format = .text

	func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.delete(Caked_DeleteRequest(command: self), callOptions: callOptions).response.wait().vms.delete

		if result.success {
			return self.format.render(result.objects)
		} else {
			return self.format.render(result.reason)
		}
	}
}
