import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Rename: GrpcParsableCommand {
	static let configuration = RenameOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Rename options")
	var rename: RenameOptions

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.rename(Caked_RenameRequest(command: self), callOptions: callOptions).response.wait().successfull().tart.message
	}
}
