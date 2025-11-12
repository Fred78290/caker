import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Import: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Import VM from a compressed .tvm file")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Argument(help: "Path to a file created with \"tart export\".")
	var path: String

	@Argument(help: "Destination VM name.")
	var name: String

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "import", arguments: arguments), callOptions: callOptions).response.wait().tart.message
	}
}
