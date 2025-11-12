import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Template: ParsableCommand {
	static let configuration: CommandConfiguration = CommandConfiguration(
		abstract: "Manage simplestream remote",
		subcommands: [CreateTemplate.self, DeleteTemplate.self, ListTemplate.self])

	struct CreateTemplate: GrpcParsableCommand {
		static let configuration = TemplateCreateOptions.configuration

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@OptionGroup(title: "Create template options")
		var template: TemplateCreateOptions

		@Flag(help: "Output format")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.template(Caked_TemplateRequest(command: self), callOptions: callOptions).response.wait().templates.create)
		}
	}

	struct DeleteTemplate: GrpcParsableCommand {
		static let configuration = TemplateDeletionOptions.configuration

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@OptionGroup(title: "Delete template options")
		var template: TemplateDeletionOptions

		@Flag(help: "Output format")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.template(Caked_TemplateRequest(command: self), callOptions: callOptions).response.wait().templates.delete)
		}
	}

	struct ListTemplate: GrpcParsableCommand {
		static let configuration = TemplateListOptions.configuration

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@Flag(help: "Output format")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.template(Caked_TemplateRequest(command: self), callOptions: callOptions).response.wait().templates.list)
		}
	}
}
