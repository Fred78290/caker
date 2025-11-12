import ArgumentParser
import Compression
import Dispatch
import Foundation
import GRPC
import GRPCLib

struct Push: GrpcParsableCommand {
	static let configuration = PushOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Push options")
	var push: PushOptions

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "push", arguments: push.arguments()), callOptions: callOptions).response.wait().tart.message
	}
}
