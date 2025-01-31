import ArgumentParser
import Foundation
import GRPCLib

struct ImagesManagement: ParsableCommand {
	static var configuration = CommandConfiguration(commandName: "image", abstract: "Manage simplestream images",
	                                                subcommands: [ListImage.self, InfoImage.self])

	struct ListImage : AsyncParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(commandName: "list", abstract: "List images")

		@Option(help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Remote name")
		var name: String

		mutating func run() async throws {
			let result = try await ImageHandler.listImage(remote: self.name, asSystem: false)

			Logger.appendNewLine(format.renderList(result))
		}
	}

	struct InfoImage : AsyncParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(commandName: "info", abstract: "Show useful information about images")

		@Option(help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Image name")
		var name: String

		mutating func run() async throws {
			let result = try await ImageHandler.info(name: self.name, asSystem: false)

			Logger.appendNewLine(format.renderSingle(result))
		}
	}
}