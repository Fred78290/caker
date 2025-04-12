import Foundation
import ArgumentParser
import GRPCLib
import Logging
import TextTable

struct Remote: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Manage simplestream remote",
	                                                subcommands: [AddRemote.self, DeleteRemote.self, ListRemote.self])

	struct AddRemote : ParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "add", abstract: "Add new remote servers")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Argument(help: "Remote name")
		var remote: String

		@Argument(help: "url")
		var url: String

		func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(try RemoteHandler.addRemote(name: self.remote, url: URL(string: self.url)!, asSystem: false))
		}
	}

	struct DeleteRemote : ParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "delete", abstract: "Remove remotes")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Argument(help: "Remote name")
		var remote: String

		func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(try RemoteHandler.deleteRemote(name: remote, asSystem: false))
		}
	}

	struct ListRemote : ParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "list", abstract: "List the available remotes")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(format.render(try RemoteHandler.listRemote(asSystem: false)))
		}
	}
}

