import ArgumentParser
import Foundation
import GRPCLib
import TextTable

struct Template: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "template",
		abstract: "Manage VM templates",
		subcommands: [
			ListTemplate.self,
			CreateTemplate.self,
			DeleteTemplate.self,
		]
	)

	struct ListTemplate: ParsableCommand {
		static let configuration = TemplateListOptions.configuration

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try TemplateHandler.listTemplate(asSystem: self.common.asSystem)))
		}
	}

	struct CreateTemplate: ParsableCommand {
		static let configuration = TemplateCreateOptions.configuration

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@OptionGroup(title: "Create template options")
		var template: TemplateCreateOptions

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try TemplateHandler.createTemplate(on: Root.group.next(), sourceName: self.template.name, templateName: self.template.template, asSystem: self.common.asSystem)))
		}
	}

	struct DeleteTemplate: ParsableCommand {
		static let configuration = TemplateDeletionOptions.configuration

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@OptionGroup(title: "Delete template options")
		var template: TemplateDeletionOptions

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try TemplateHandler.deleteTemplate(templateName: self.template.name, asSystem: self.common.asSystem)))
		}
	}
}
