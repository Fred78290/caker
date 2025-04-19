import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Clone: GrpcParsableCommand {
	static let configuration = CloneOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Clone options")
	var clone: CloneOptions

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.clone(Caked_CloneRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.message
	}
}
