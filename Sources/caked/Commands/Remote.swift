import Foundation
import ArgumentParser
import GRPCLib
import Logging
import TextTable

struct Remote: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Manage simplestream remote",
	                                                subcommands: [AddRemote.self, DeleteRemote.self, ListRemote.self])

	struct AddRemote : ParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(abstract: "Add new remote servers")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Argument(help: "Remote name")
		var remote: String

		@Argument(help: "url")
		var url: String

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		mutating func run() throws {
			Logger.appendNewLine(try RemoteHandler.addRemote(name: self.remote, url: URL(string: self.url)!, asSystem: false))
		}
	}

	struct DeleteRemote : ParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(abstract: "Remove remotes")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Argument(help: "Remote name")
		var remote: String

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		mutating func run() throws {
			Logger.appendNewLine(try RemoteHandler.deleteRemote(name: remote, asSystem: false))
		}
	}

	struct ListRemote : ParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(abstract: "List the available remotes")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(help: "Output format: text or json")
		var format: Format = .text

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		mutating func run() throws {
			let result: [RemoteEntry] = try RemoteHandler.listRemote(asSystem: false)

			Logger.appendNewLine(format.renderList(style: Style.grid, uppercased: true, result))
		}
	}
}

