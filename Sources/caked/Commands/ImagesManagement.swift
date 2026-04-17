import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import CakeAgentLib

struct ImagesManagement: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "image", abstract: String(localized: "Manage simplestream images"),
		subcommands: [ListImage.self, InfoImage.self, PullImage.self])

	struct ListImage: AsyncParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "list", abstract: String(localized: "List images"), aliases: ["ls"])

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@Argument(help: ArgumentHelp(String(localized: "Remote name")))
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() async throws {
			let result = await CakedLib.ImageHandler.listImage(remote: self.name, runMode: self.common.runMode)

			if result.success {
				Logger.appendNewLine(self.common.format.render(result.infos))
			} else {
				Logger.appendNewLine(self.common.format.render(result.reason))
			}
		}
	}

	struct InfoImage: AsyncParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "info", abstract: String(localized: "Show useful information about images"))

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@Argument(help: ArgumentHelp(String(localized: "Image name")))
		var name: String

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() async throws {
			let result = await CakedLib.ImageHandler.info(name: self.name, runMode: self.common.runMode)

			if result.success {
				Logger.appendNewLine(self.common.format.render(result.info))
			} else {
				Logger.appendNewLine(self.common.format.render(result.reason))
			}
		}
	}

	struct PullImage: AsyncParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "pull", abstract: String(localized: "Pull image"))

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@Argument(help: ArgumentHelp(String(localized: "Image name")))
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() async throws {
			let result = await CakedLib.ImageHandler.pull(name: self.name, runMode: self.common.runMode)

			if result.success {
				Logger.appendNewLine(self.common.format.render(result.info))
			} else {
				Logger.appendNewLine(self.common.format.render(result.reason))
			}
		}
	}
}
