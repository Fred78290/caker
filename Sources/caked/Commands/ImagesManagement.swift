import ArgumentParser
import Foundation
import GRPCLib
import Logging
import TextTable

struct ImagesManagement: ParsableCommand {
	static let configuration = CommandConfiguration(commandName: "image", abstract: "Manage simplestream images",
	                                                subcommands: [ListImage.self, InfoImage.self, PullImage.self])

	struct ListImage : AsyncParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "list", abstract: "List images")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Remote name")
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		func run() async throws {
			Logger.appendNewLine(try await ImageHandler.listImage(remote: self.name, asSystem: false).formatedOutput(format: self.format))
		}
	}

	struct InfoImage : AsyncParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "info", abstract: "Show useful information about images")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Image name")
		var name: String

		func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		func run() async throws {
			Logger.appendNewLine(try await ImageHandler.info(name: self.name, asSystem: false).formatedOutput(format: self.format))
		}
	}

	struct PullImage : AsyncParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "pull", abstract: "Pull image")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Image name")
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		func run() async throws {
			Logger.appendNewLine(try await ImageHandler.pull(name: self.name, asSystem: false).formatedOutput(format: self.format))
		}
	}
}
