import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI

struct Pull: GrpcParsableCommand {
	static let configuration = PullOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Pull options")
	var pull: PullOptions

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.clone(Caked_CloneRequest(command: self), callOptions: callOptions).response.wait().oci.pull)
	}
}
