import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Rename: GrpcParsableCommand {
	static let configuration = RenameOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Rename options"))
	var rename: RenameOptions

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.options.format.render(try client.rename(Caked_RenameRequest(command: self), callOptions: callOptions).response.wait().vms.renamed)
	}
}
