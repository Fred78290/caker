import ArgumentParser
import Foundation
import GRPCLib
import Logging
import TextTable

struct Remote: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Manage simplestream remote",
		subcommands: [AddRemote.self, DeleteRemote.self, ListRemote.self])

	struct AddRemote: ParsableCommand {
		static let configuration = RemoteAddOptions.configuration

		@OptionGroup(title: "Global options")
		var common: CommonOptions

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

	struct DeleteRemote: ParsableCommand {
		static let configuration = RemoteDeleteOptions.configuration

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@Argument(help: "Remote name")
		var remote: String

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try RemoteHandler.deleteRemote(name: remote, asSystem: self.common.asSystem)))
		}
	}

	struct ListRemote: ParsableCommand {
		static let configuration = RemoteListOptions.configuration

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try RemoteHandler.listRemote(asSystem: self.common.asSystem)))
		}
	}
}
