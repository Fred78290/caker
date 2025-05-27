import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Start: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Launch a linux VM create in background")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Argument(help: "VM name")
	var name: String

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.start(Caked_StartRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.message
	}
}
