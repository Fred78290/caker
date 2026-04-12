import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI
import CakeAgentLib

struct Pull: GrpcParsableCommand {
	static let configuration = PullOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Pull options"))
	var pull: PullOptions

	@Flag(help: ArgumentHelp(String(localized: "Output format: text or json")))
	var format: Format = .text

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.clone(Caked_CloneRequest(command: self), callOptions: callOptions).response.wait().oci.pull)
	}
}
