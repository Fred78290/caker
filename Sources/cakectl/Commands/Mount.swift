import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI
import CakeAgentLib

struct Mount: GrpcParsableCommand {
	static let configuration = MountOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Mount options")
	var mount: MountOptions

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.mount(Caked_MountRequest(command: self), callOptions: callOptions).response.wait().mounts

		if result.success {
			return self.format.render(result.mounts)
		} else {
			return self.format.render(result.reason)
		}
	}
}
