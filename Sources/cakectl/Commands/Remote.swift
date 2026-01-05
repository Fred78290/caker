import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Remote: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Manage simplestream remote",
		subcommands: [AddRemote.self, DeleteRemote.self, ListRemote.self])

	struct AddRemote: GrpcParsableCommand {
		static let configuration = RemoteAddOptions.configuration

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@Argument(help: "Remote name")
		var remote: String

		@Argument(help: "url")
		var url: String

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.remote(Caked_RemoteRequest(command: self), callOptions: callOptions).response.wait().remotes.created)
		}
	}

	struct DeleteRemote: GrpcParsableCommand {
		static let configuration = RemoteDeleteOptions.configuration

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@Argument(help: "Remote name")
		var remote: String

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.remote(Caked_RemoteRequest(command: self), callOptions: callOptions).response.wait().remotes.deleted)
		}
	}

	struct ListRemote: GrpcParsableCommand {
		static let configuration = RemoteListOptions.configuration

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let result = try client.remote(Caked_RemoteRequest(command: self), callOptions: callOptions).response.wait().remotes.list

			if result.success {
				return self.format.render(result.remotes)
			} else {
				return self.format.render(result.reason)
			}
		}
	}
}
