import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Export: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Export VM to a compressed .tvm file")

	@OptionGroup var options: Client.Options

	@Argument(help: "Source VM name.")
	var name: String

	@Argument(help: "Path to the destination file.")
	var path: String?

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "export", arguments: arguments), callOptions: callOptions).response.wait()
	}
}
