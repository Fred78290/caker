import Foundation
import ArgumentParser
import GRPCLib
import TextTable

struct Template: ParsableCommand {
	static let configuration = CommandConfiguration(commandName: "template",
	                                                abstract: "Manage VM templates",
	                                                subcommands: [
	                                                	ListTemplate.self,
	                                                	CreateTemplate.self,
	                                                	DeleteTemplate.self
	                                                ]
	)

	struct ListTemplate: ParsableCommand {
		static let configuration = CommandConfiguration(commandName: "list", abstract: "List templates")

		@Option(name: .shortAndLong, help: "Output format")
		var format: Format = .text

		func run() throws {
			Logger.appendNewLine(self.format.render(try TemplateHandler.listTemplate(asSystem: runAsSystem)))
		}
	}

	struct CreateTemplate: ParsableCommand {
		static let configuration = CommandConfiguration(commandName: "create", abstract: "Create template from existing VM")

		@Argument(help: "Source VM name")
		var name: String

		@Argument(help: "Template name")
		var template: String

		@Option(name: .shortAndLong, help: "Output format")
		var format: Format = .text

		func run() throws {			
			Logger.appendNewLine(self.format.render(try TemplateHandler.createTemplate(on: Root.group.next(), sourceName: name, templateName: template, asSystem: false)))
		}
	}

	struct DeleteTemplate: ParsableCommand {
		static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete template")

		@Argument(help: "Template name")
		var name: String

		@Option(name: .shortAndLong, help: "Output format")
		var format: Format = .text

		func run() throws {
			Logger.appendNewLine(self.format.render(try TemplateHandler.deleteTemplate(templateName: name, asSystem: false)))
		}
	}
}
