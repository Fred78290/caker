import ArgumentParser
import Logging

struct WaitIP: ParsableCommand {
	static let configuration = CommandConfiguration(commandName: "waitip", abstract: "Wait for ip of a running VM")

	@OptionGroup var common: CommonOptions

	@Argument(help: "VM name")
	var name: String

	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
	var wait: Int = 0

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try WaitIPHandler.waitIP(name: self.name, wait: self.wait, asSystem: self.common.asSystem)))
	}
}
