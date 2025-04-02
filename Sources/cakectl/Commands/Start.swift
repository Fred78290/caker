import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Start: GrpcParsableCommand {
	static let configuration = CommandConfiguration(commandName: "start", abstract: "Launch a linux VM create in background")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.start(Caked_StartRequest(command: self), callOptions: callOptions).response.wait()
	}
}
