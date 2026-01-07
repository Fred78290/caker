import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import CakeAgentLib

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
			let result = CakedLib.TemplateHandler.listTemplate(runMode: self.common.runMode)

			if result.success {
				Logger.appendNewLine(self.common.format.render(result.templates))
			} else {
				Logger.appendNewLine(self.common.format.render(result.reason))
			}
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
			Logger.appendNewLine(self.common.format.render(CakedLib.TemplateHandler.createTemplate(on: Utilities.group.next(), sourceName: self.template.name, templateName: self.template.template, runMode: self.common.runMode)))
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
			Logger.appendNewLine(self.common.format.render(CakedLib.TemplateHandler.deleteTemplate(templateName: self.template.name, runMode: self.common.runMode)))
		}
	}
}
