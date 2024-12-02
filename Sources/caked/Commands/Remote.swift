import Foundation
import ArgumentParser
import GRPCLib

struct Remote: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Manage simplestream remote",
	                                                subcommands: [AddRemote.self, DeleteRemote.self, ListRemote.self])

	struct AddRemote : ParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(abstract: "Add new remote servers")

		@Argument(help: "Remote name")
		var remote: String

		@Argument(help: "url")
		var url: String

		mutating func run() throws {
			Logger.appendNewLine(try RemoteHandler.addRemote(name: self.remote, url: URL(string: self.url)!, asSystem: false))
		}
	}

	struct DeleteRemote : ParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(abstract: "Remove remotes")

		@Argument(help: "Remote name")
		var remote: String

		mutating func run() throws {
			Logger.appendNewLine(try RemoteHandler.deleteRemote(name: remote, asSystem: false))
		}
	}

	struct ListRemote : ParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(abstract: "List the available remotes")

		@Option(help: "Output format: text or json")
		var format: Format = .text

		mutating func run() throws {
			let result = try RemoteHandler.listRemote(asSystem: false)

			Logger.appendNewLine(format.renderList(result))
		}
	}
}

