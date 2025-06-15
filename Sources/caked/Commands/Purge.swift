import ArgumentParser
import GRPCLib
import Logging
import CakedLib

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
		Logger.appendNewLine(self.common.format.render(try CakedLib.PurgeHandler.purge(direct: true, runMode: self.common.runMode, options: self.purge)))
	}
}
