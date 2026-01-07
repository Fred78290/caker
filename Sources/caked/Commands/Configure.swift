import ArgumentParser
import CakedLib
import GRPCLib
import CakeAgentLib
import Virtualization

struct Configure: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Reconfigure VM")

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Configure options")
	var options: ConfigureOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(CakedLib.ConfigureHandler.configure(name: self.options.name, options: options, runMode: self.common.runMode)))
	}
}
