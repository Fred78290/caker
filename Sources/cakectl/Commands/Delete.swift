import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import TextTable
import CakeAgentLib

struct Delete: GrpcParsableCommand {
	static let configuration: CommandConfiguration = DeleteOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Delete options"))
	var delete: DeleteOptions

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.delete(Caked_DeleteRequest(command: self), callOptions: callOptions).response.wait().vms.delete

		if result.success {
			return self.options.format.render(result.objects)
		} else {
			return self.options.format.render(result.reason)
		}
	}
}
