import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC

struct Pull: GrpcParsableCommand {
	static let configuration = PullOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Pull options")
	var pull: PullOptions

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "pull", arguments: pull.arguments()), callOptions: callOptions).response.wait().successfull().tart.message
	}
}
