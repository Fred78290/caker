import ArgumentParser
import CakedLib
import GRPCLib
import CakeAgentLib
import Virtualization

struct Configure: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: String(localized: "Reconfigure VM"))

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@OptionGroup(title: String(localized: "Configure options"))
	var options: ConfigureOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(CakedLib.ConfigureHandler.configure(name: self.options.name, options: options, runMode: self.common.runMode)))
	}
}
