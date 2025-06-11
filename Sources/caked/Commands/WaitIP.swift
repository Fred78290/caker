import ArgumentParser
import GRPCLib
import Logging

struct WaitIP: ParsableCommand {
	static let configuration = WaitIPOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Wait ip options")
	var waitip: WaitIPOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try WaitIPHandler.waitIP(name: self.waitip.name, wait: self.waitip.wait, runMode: self.common.runMode)))
	}
}
