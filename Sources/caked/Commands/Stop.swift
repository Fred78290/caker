import ArgumentParser
import GRPCLib
import Logging

struct Stop: ParsableCommand {
	static let configuration = StopOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Global options")
	var stop: StopOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try StopHandler.stopVMs(all: self.stop.all, names: self.stop.names, force: self.stop.force, asSystem: self.common.asSystem)))
	}
}
