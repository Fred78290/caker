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

		@OptionGroup var common: CommonOptions

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try TemplateHandler.listTemplate(asSystem: self.common.asSystem)))
		}
	}

	struct CreateTemplate: ParsableCommand {
		static let configuration = CommandConfiguration(commandName: "create", abstract: "Create template from existing VM")

		@OptionGroup var common: CommonOptions

		@Argument(help: "Source VM name")
		var name: String

		@Argument(help: "Template name")
		var template: String

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {			
			Logger.appendNewLine(self.common.format.render(try TemplateHandler.createTemplate(on: Root.group.next(), sourceName: name, templateName: template, asSystem: self.common.asSystem)))
		}
	}

	struct DeleteTemplate: ParsableCommand {
		static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete template")

		@OptionGroup var common: CommonOptions

		@Argument(help: "Template name")
		var name: String

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try TemplateHandler.deleteTemplate(templateName: name, asSystem: self.common.asSystem)))
		}
	}
}
