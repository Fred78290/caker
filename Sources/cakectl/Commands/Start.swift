import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Start: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Launch a linux VM create in background")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Argument(help: "VM name")
	var name: String

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.start(Caked_StartRequest(command: self), callOptions: callOptions).response.wait().vms.started)
	}
}
