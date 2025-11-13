import ArgumentParser
import CakedLib
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
		let result = CakedLib.StopHandler.stopVMs(all: self.stop.all, names: self.stop.names, force: self.stop.force, runMode: self.common.runMode)

		if result.success {
			Logger.appendNewLine(self.common.format.render(result.objects))
		} else {
			Logger.appendNewLine(self.common.format.render(result.reason))
		}
	}
}
