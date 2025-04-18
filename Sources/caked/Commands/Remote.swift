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

		@OptionGroup var common: CommonOptions

		@Argument(help: "Remote name")
		var remote: String

		@Argument(help: "url")
		var url: String

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try RemoteHandler.addRemote(name: self.remote, url: URL(string: self.url)!, asSystem: self.common.asSystem)))
		}
	}

	struct DeleteRemote : ParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "delete", abstract: "Remove remotes")

		@OptionGroup var common: CommonOptions

		@Argument(help: "Remote name")
		var remote: String

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try RemoteHandler.deleteRemote(name: remote, asSystem: self.common.asSystem)))
		}
	}

	struct ListRemote : ParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "list", abstract: "List the available remotes")

		@OptionGroup var common: CommonOptions

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try RemoteHandler.listRemote(asSystem: self.common.asSystem)))
		}
	}
}

