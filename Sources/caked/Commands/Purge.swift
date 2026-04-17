import ArgumentParser
import CakedLib
import GRPCLib
import CakeAgentLib

struct Purge: ParsableCommand {
	static let configuration = PurgeOptions.configuration

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@OptionGroup(title: String(localized: "Purge options"))
	var purge: PurgeOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(CakedLib.PurgeHandler.purge(direct: true, runMode: self.common.runMode, options: self.purge)))
	}
}
