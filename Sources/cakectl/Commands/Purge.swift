import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Purge: GrpcParsableCommand {
	static let configuration = PurgeOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Purge options")
	var purge: PurgeOptions

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.purge(Caked_PurgeRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.message
	}
}
