import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import CakeAgentLib

struct Aliases: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "aliases",
		abstract: String(localized: "List catalog image ids usable with build/launch --alias"),
		discussion: String(localized: "Lists every id from VMImages.json for the current architecture, e.g. macos12, ubuntu2604, fedora44Server.")
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(VMImageCatalog.shared.aliasEntries))
	}
}
