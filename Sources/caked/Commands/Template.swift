import Foundation
import ArgumentParser

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

		func run() throws {
			print("Running subcommand")
		}
	}

	struct CreateTemplate: ParsableCommand {
		static var configuration = CommandConfiguration(commandName: "create", abstract: "Create template from existing VM")

		@Option(name: .shortAndLong, help: "Source VM name")
		var name: String

		@Option(name: .shortAndLong, help: "Template name")
		var template: String

		func run() throws {
			let storage = StorageLocation(asSystem: false, name: "templates")
		}
	}

	struct DeleteTemplate: ParsableCommand {
		static var configuration = CommandConfiguration(commandName: "delete", abstract: "Delete template")

		@Option(name: .shortAndLong, help: "Template name")
		var name: String

		func run() throws {
			let storage = StorageLocation(asSystem: false, name: "templates")
			let location = try storage.find(name)

			storage.delete()
		}
	}
}