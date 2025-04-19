import ArgumentParser
import Logging
import GRPCLib

struct Purge: ParsableCommand {
	static let configuration = PurgeOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Purge options")
	var purge: PurgeOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try PurgeHandler.purge(direct: true, asSystem: self.common.asSystem, options: self.purge)))
	}
}
