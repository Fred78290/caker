import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Remote: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: String(localized: "Manage simplestream remote"),
		subcommands: [AddRemote.self, DeleteRemote.self, ListRemote.self])

	struct AddRemote: GrpcParsableCommand {
		static let configuration = RemoteAddOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "Remote name")))
		var remote: String

		@Argument(help: ArgumentHelp(String(localized: "url")))
		var url: String

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.options.format.render(try client.remote(Caked_RemoteRequest(command: self), callOptions: callOptions).response.wait().remotes.created)
		}
	}

	struct DeleteRemote: GrpcParsableCommand {
		static let configuration = RemoteDeleteOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "Remote name")))
		var remote: String

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.options.format.render(try client.remote(Caked_RemoteRequest(command: self), callOptions: callOptions).response.wait().remotes.deleted)
		}
	}

	struct ListRemote: GrpcParsableCommand {
		static let configuration = RemoteListOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let result = try client.remote(Caked_RemoteRequest(command: self), callOptions: callOptions).response.wait().remotes.list

			if result.success {
				return self.options.format.render(result.remotes)
			} else {
				return self.options.format.render(result.reason)
			}
		}
	}
}
