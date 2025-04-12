import Foundation
import ArgumentParser
import GRPCLib
import GRPC

struct Remote: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Manage simplestream remote",
	                                                subcommands: [AddRemote.self, DeleteRemote.self, ListRemote.self])

	struct AddRemote : GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "add", abstract: "Add new remote servers")

		@OptionGroup var options: Client.Options

		@Argument(help: "Remote name")
		var remote: String

		@Argument(help: "url")
		var url: String

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return try client.remote(Caked_RemoteRequest(command: self), callOptions: callOptions).response.wait().successfull().remotes.message
		}
	}

	struct DeleteRemote : GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "delete", abstract: "Remove remotes")

		@OptionGroup var options: Client.Options

		@Argument(help: "Remote name")
		var remote: String

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return try client.remote(Caked_RemoteRequest(command: self), callOptions: callOptions).response.wait().successfull().remotes.message
		}
	}

	struct ListRemote : GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "list", abstract: "List the available remotes")

		@OptionGroup var options: Client.Options

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.remote(Caked_RemoteRequest(command: self), callOptions: callOptions).response.wait().successfull().remotes.list)
		}
	}
}

