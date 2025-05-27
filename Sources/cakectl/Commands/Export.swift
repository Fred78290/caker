import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Export: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Export VM to a compressed .tvm file")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Argument(help: "Source VM name.")
	var name: String

	@Argument(help: "Path to the destination file.")
	var path: String?

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		try client.cakeCommand(Caked_CakedCommandRequest(command: "export", arguments: arguments), callOptions: callOptions).response.wait().successfull().tart.message
	}
}
