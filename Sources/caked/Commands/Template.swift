import Foundation
import ArgumentParser
import GRPCLib
import TextTable

struct Template: ParsableCommand {
	static var configuration = CommandConfiguration(commandName: "template",
	                                                abstract: "Manage VM templates",
	                                                subcommands: [
	                                                	ListTemplate.self,
	                                                	CreateTemplate.self,
	                                                	DeleteTemplate.self
	                                                ]
	)

	struct ListTemplate: ParsableCommand {
		static var configuration = CommandConfiguration(commandName: "list", abstract: "List templates")

		@Option(name: .shortAndLong, help: "Output format")
		var format: Format = .text

		func run() throws {
			if format == .json {
				print(format.renderList(style: Style.grid, uppercased: true, try TemplateHandler.listTemplate(asSystem: runAsSystem)))
			} else {
				print(format.renderList(style: Style.grid, uppercased: true, try TemplateHandler.listTemplate(asSystem: runAsSystem).map { TemplateHandler.ShortTemplateEntry($0) }))
			}
		}
	}

	struct CreateTemplate: ParsableCommand {
		static var configuration = CommandConfiguration(commandName: "create", abstract: "Create template from existing VM")

		@Argument(help: "Source VM name")
		var name: String

		@Argument(help: "Template name")
		var template: String

		@Option(name: .shortAndLong, help: "Output format")
		var format: Format = .text

		func run() throws {			
			print(self.format.renderSingle(style: Style.grid, uppercased: true, try TemplateHandler.createTemplate(on: Root.group.next(), sourceName: name, templateName: template, asSystem: false)))
		}
	}

	struct DeleteTemplate: ParsableCommand {
		static var configuration = CommandConfiguration(commandName: "delete", abstract: "Delete template")

		@Argument(help: "Template name")
		var name: String

		@Option(name: .shortAndLong, help: "Output format")
		var format: Format = .text

		func run() throws {
			print(format.renderSingle(style: Style.grid, uppercased: true, try TemplateHandler.deleteTemplate(templateName: name, asSystem: false)))
		}
	}
}