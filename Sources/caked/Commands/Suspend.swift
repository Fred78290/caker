import ArgumentParser
import CakedLib
import GRPCLib
import CakeAgentLib

struct Suspend: ParsableCommand {
	static let configuration = CommandConfiguration(commandName: "suspend", abstract: "Suspend VM(s)", aliases: ["pause"])

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@Argument(help: "VM names to suspend")
	var names: [String] = []

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		let result = CakedLib.SuspendHandler.suspendVMs(names: self.names, runMode: self.common.runMode)

		if result.success {
			Logger.appendNewLine(self.common.format.render(result.objects))
		} else {
			Logger.appendNewLine(self.common.format.render(result.reason))
		}
	}
}
