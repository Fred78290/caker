import ArgumentParser
import Logging

struct Stop: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Stop VM")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Flag(help: "Force stop")
	var force: Bool = false

	@Argument(help: "VM name")
	var name: String

	func validate() throws {
		Logger.setLevel(self.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(try StopHandler.stopVM(name: self.name, force: self.force, asSystem: false))
	}
}
