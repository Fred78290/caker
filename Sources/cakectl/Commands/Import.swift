import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Import: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Import VM from a compressed .tvm file")

	@OptionGroup var options: Client.Options

	@Argument(help: "Path to a file created with \"tart export\".")
	var path: String

	@Argument(help: "Destination VM name.")
	var name: String

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "import", arguments: arguments), callOptions: callOptions).response.wait()
	}
}
