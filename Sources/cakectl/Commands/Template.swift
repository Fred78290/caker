import Foundation
import ArgumentParser
import GRPCLib
import GRPC

struct Template: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Manage simplestream remote",
	                                                subcommands: [CreateTemplate.self, DeleteTemplate.self, ListTemplate.self])

	struct CreateTemplate : GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "create", abstract: "Add new remote servers")

		@OptionGroup var options: Client.Options

		@Argument(help: "Source VM name")
		var name: String

		@Argument(help: "Template name")
		var template: String

		@Option(name: .shortAndLong, help: "Output format")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.template(Caked_TemplateRequest(command: self), callOptions: callOptions).response.wait()
		}
	}

	struct DeleteTemplate : GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "delete", abstract: "Remove remotes")

		@OptionGroup var options: Client.Options

		@Argument(help: "Template name")
		var name: String

		@Option(name: .shortAndLong, help: "Output format")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.template(Caked_TemplateRequest(command: self), callOptions: callOptions).response.wait()
		}
	}

	struct ListTemplate : GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "list", abstract: "List the available remotes")

		@OptionGroup var options: Client.Options

		@Option(name: .shortAndLong, help: "Output format")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.template(Caked_TemplateRequest(command: self), callOptions: callOptions).response.wait()
		}
	}
}

