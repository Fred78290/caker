import ArgumentParser
import CakedLib
import GRPCLib
import Logging

struct Suspend: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Suspend VM(s)")

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@Argument(help: "VM names to suspend")
	var names: [String] = []

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try CakedLib.SuspendHandler.suspendVMs(names: self.names, runMode: self.common.runMode)))
	}
}
