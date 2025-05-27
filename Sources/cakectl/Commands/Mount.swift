import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI

struct Mount: GrpcParsableCommand {
	static let configuration = MountOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Mount options")
	var mount: MountOptions

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.mount(Caked_MountRequest(command: self), callOptions: callOptions).response.wait().successfull().mounts)
	}
}
