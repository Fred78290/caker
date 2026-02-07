import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Rename: GrpcParsableCommand {
	static let configuration = RenameOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Rename options")
	var rename: RenameOptions

	@Flag(help: "Output format")
	var format: Format = .text

	func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.rename(Caked_RenameRequest(command: self), callOptions: callOptions).response.wait().vms.renamed)
	}
}
