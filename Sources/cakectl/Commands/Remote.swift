import Foundation
import ArgumentParser
import GRPCLib
import GRPC

struct Remote: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Manage simplestream remote",
	                                                subcommands: [AddRemote.self, DeleteRemote.self, ListRemote.self])

	struct AddRemote : GrpcParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(abstract: "Add new remote servers")

		@OptionGroup var options: Client.Options

		@Argument(help: "Remote name")
		var remote: String

		@Argument(help: "url")
		var url: String

		func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.remote(Caked_RemoteRequest(command: self), callOptions: callOptions).response.wait()
		}
	}

	struct DeleteRemote : GrpcParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(abstract: "Remove remotes")

		@OptionGroup var options: Client.Options

		@Argument(help: "Remote name")
		var remote: String

		func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.remote(Caked_RemoteRequest(command: self), callOptions: callOptions).response.wait()
		}
	}

	struct ListRemote : GrpcParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(abstract: "List the available remotes")

		@OptionGroup var options: Client.Options

		@Option(help: "Output format: text or json")
		var format: Format = .text

		func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.remote(Caked_RemoteRequest(command: self), callOptions: callOptions).response.wait()
		}
	}
}

