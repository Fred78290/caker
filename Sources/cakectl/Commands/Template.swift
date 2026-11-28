import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Template: ParsableCommand {
	static let configuration: CommandConfiguration = CommandConfiguration(
		abstract: String(localized: "Manage simplestream remote"),
		subcommands: [CreateTemplate.self, DeleteTemplate.self, DuplicateTemplate.self, InfosTemplate.self, ListTemplate.self])

	struct CreateTemplate: AsyncGrpcParsableCommand {
		static let configuration = TemplateCreateOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@OptionGroup(title: String(localized: "Create template options"))
		var template: TemplateCreateOptions

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
			let taskID = UUID()

			// Ctrl-C asks caked to cancel: it kills and deletes the temporary VM and a template being written.
			return try await Client.cancellingTaskOnInterrupt(
				client: client, callOptions: callOptions, taskID: taskID, attemptTimeLimit: CakedServiceClient.longCancelTaskTimeLimit,
				succeeded: { $0.templates.create.created },
				render: { self.options.format.render($0.templates.create) }
			) {
				try await client.template(Caked_TemplateRequest(command: self, taskID: taskID), callOptions: callOptions).response.get()
			}
		}
	}

	struct DeleteTemplate: GrpcParsableCommand {
		static let configuration = TemplateDeletionOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@OptionGroup(title: String(localized: "Delete template options"))
		var template: TemplateDeletionOptions

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.options.format.render(try client.template(Caked_TemplateRequest(command: self), callOptions: callOptions).response.wait().templates.delete)
		}
	}

	struct DuplicateTemplate: GrpcParsableCommand {
		static let configuration = TemplateDuplicateOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@OptionGroup(title: String(localized: "Duplicate template options"))
		var template: TemplateDuplicateOptions

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.options.format.render(try client.template(Caked_TemplateRequest(command: self), callOptions: callOptions).response.wait().templates.duplicate)
		}
	}

	struct InfosTemplate: GrpcParsableCommand {
		static let configuration = TemplateInfosOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@OptionGroup(title: String(localized: "Infos template options"))
		var template: TemplateInfosOptions

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let result = try client.template(Caked_TemplateRequest(command: self), callOptions: callOptions).response.wait().templates.infos

			if result.success {
				return self.options.format.render(result.infos)
			} else {
				return self.options.format.render(result.reason)
			}
		}
	}

	struct ListTemplate: GrpcParsableCommand {
		static let configuration = TemplateListOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.options.format.render(try client.template(Caked_TemplateRequest(command: self), callOptions: callOptions).response.wait().templates.list)
		}
	}
}
