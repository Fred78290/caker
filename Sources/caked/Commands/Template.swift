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
			print(format.renderList(style: Style.grid, uppercased: true, try TemplateHandler.listTemplate(asSystem: false)))
		}
	}

	struct CreateTemplate: AsyncParsableCommand {
		static var configuration = CommandConfiguration(commandName: "create", abstract: "Create template from existing VM")

		@Argument(help: "Source VM name")
		var name: String

		@Argument(help: "Template name")
		var template: String

		@Option(name: .shortAndLong, help: "Output format")
		var format: Format = .text

		func run() async throws {
			let r = try TemplateHandler.createTemplate(on: Root.group.next(), sourceName: name, templateName: template, asSystem: false)
			
			r.whenSuccess { reply in
				print(self.format.renderSingle(style: Style.grid, uppercased: true, reply))
				Foundation.exit(0)
			}

			r.whenFailure { error in
				FileHandle.standardError.write("\(error.localizedDescription)\n".data(using: .utf8)!)
				Foundation.exit(0)
			}

			print(self.format.renderSingle(style: Style.grid, uppercased: true, try await r.get()))
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