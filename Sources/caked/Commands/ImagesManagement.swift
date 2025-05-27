import ArgumentParser
import Foundation
import GRPCLib
import Logging
import TextTable

struct ImagesManagement: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "image", abstract: "Manage simplestream images",
		subcommands: [ListImage.self, InfoImage.self, PullImage.self])

	struct ListImage: AsyncParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "list", abstract: "List images")

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@Argument(help: "Remote name")
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() async throws {
			Logger.appendNewLine(self.common.format.render(try await ImageHandler.listImage(remote: self.name, asSystem: self.common.asSystem)))
		}
	}

	struct InfoImage: AsyncParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "info", abstract: "Show useful information about images")

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@Argument(help: "Image name")
		var name: String

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() async throws {
			Logger.appendNewLine(self.common.format.render(try await ImageHandler.info(name: self.name, asSystem: self.common.asSystem)))
		}
	}

	struct PullImage: AsyncParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "pull", abstract: "Pull image")

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@Argument(help: "Image name")
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() async throws {
			Logger.appendNewLine(self.common.format.render(try await ImageHandler.pull(name: self.name, asSystem: self.common.asSystem)))
		}
	}
}
