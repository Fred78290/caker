import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import TextTable
import CakeAgentLib

struct Duplicate: GrpcParsableCommand {
	static let configuration = DuplicateOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Duplicate options"))
	var duplicate: DuplicateOptions

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.options.format.render(try client.duplicate(Caked_DuplicateRequest(command: self), callOptions: callOptions).response.wait().vms.duplicated)
	}
}
