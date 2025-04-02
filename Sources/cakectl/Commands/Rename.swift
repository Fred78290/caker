import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Rename: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Rename a local VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String

	@Argument(help: "new VM name")
	var newName: String

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.rename(Caked_RenameRequest(command: self), callOptions: callOptions).response.wait()
	}
}
