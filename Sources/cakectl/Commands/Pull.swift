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

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.options.format.render(try client.clone(Caked_CloneRequest(command: self), callOptions: callOptions).response.wait().oci.pull)
	}
}
