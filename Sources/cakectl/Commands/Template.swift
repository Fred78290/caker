import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Template: ParsableCommand {
	static let configuration: CommandConfiguration = CommandConfiguration(
		abstract: String(localized: "Manage simplestream remote"),
		subcommands: [CreateTemplate.self, DeleteTemplate.self, ListTemplate.self])

	struct CreateTemplate: GrpcParsableCommand {
		static let configuration = TemplateCreateOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@OptionGroup(title: String(localized: "Create template options"))
		var template: TemplateCreateOptions

		@Flag(help: ArgumentHelp(String(localized: "Output format")))
		var format: Format = .text

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.template(Caked_TemplateRequest(command: self), callOptions: callOptions).response.wait().templates.create)
		}
	}

	struct DeleteTemplate: GrpcParsableCommand {
		static let configuration = TemplateDeletionOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@OptionGroup(title: String(localized: "Delete template options"))
		var template: TemplateDeletionOptions

		@Flag(help: ArgumentHelp(String(localized: "Output format")))
		var format: Format = .text

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.template(Caked_TemplateRequest(command: self), callOptions: callOptions).response.wait().templates.delete)
		}
	}

	struct ListTemplate: GrpcParsableCommand {
		static let configuration = TemplateListOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Flag(help: ArgumentHelp(String(localized: "Output format")))
		var format: Format = .text

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.template(Caked_TemplateRequest(command: self), callOptions: callOptions).response.wait().templates.list)
		}
	}
}
