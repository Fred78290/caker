import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import CakeAgentLib

struct Template: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "template",
		abstract: String(localized: "Manage VM templates"),
		subcommands: [
			ListTemplate.self,
			CreateTemplate.self,
			DeleteTemplate.self,
			DuplicateTemplate.self,
			InfosTemplate.self,
		],
		aliases: ["tmpl"]
	)

	struct ListTemplate: ParsableCommand {
		static let configuration = TemplateListOptions.configuration

		@OptionGroup(title: String(localized: "Global options"))
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

	struct CreateTemplate: AsyncParsableCommand {
		static let configuration = TemplateCreateOptions.configuration

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@OptionGroup(title: String(localized: "Create template options"))
		var template: TemplateCreateOptions

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() async throws {
			let (sourceName, templateName, runMode) = (self.template.name, self.template.template, self.common.runMode)
			let startMode: CakedLib.StartHandler.StartMode = self.template.foreground ? .foreground : .attach

			// Ctrl-C cancels: the temporary VM is killed and deleted, and so is a template being written.
			let reply = await Root.runCancellingOnInterrupt {
				await CakedLib.TemplateHandler.createTemplate(sourceName: sourceName, templateName: templateName, startMode: startMode, runMode: runMode)
			}

			Logger.appendNewLine(self.common.format.render(reply))
		}
	}

	struct DeleteTemplate: ParsableCommand {
		static let configuration = TemplateDeletionOptions.configuration

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@OptionGroup(title: String(localized: "Delete template options"))
		var template: TemplateDeletionOptions

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(CakedLib.TemplateHandler.deleteTemplate(templateName: self.template.name, runMode: self.common.runMode)))
		}
	}

	struct DuplicateTemplate: ParsableCommand {
		static let configuration = TemplateDuplicateOptions.configuration

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@OptionGroup(title: String(localized: "Duplicate template options"))
		var template: TemplateDuplicateOptions

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(CakedLib.TemplateHandler.duplicateTemplate(sourceName: self.template.name, templateName: self.template.template, runMode: self.common.runMode)))
		}
	}

	struct InfosTemplate: ParsableCommand {
		static let configuration = TemplateInfosOptions.configuration

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@OptionGroup(title: String(localized: "Infos template options"))
		var template: TemplateInfosOptions

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			let result = CakedLib.TemplateHandler.infos(templateName: self.template.name, runMode: self.common.runMode)

			if result.success, let infos = result.infos {
				Logger.appendNewLine(self.common.format.render(infos))
			} else {
				Logger.appendNewLine(self.common.format.render(result.reason))
			}
		}
	}
}
