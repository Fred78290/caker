import ArgumentParser
import Logging

struct WaitIP: ParsableCommand {
	static var configuration = CommandConfiguration(commandName: "waitip", abstract: "Run linux VM in background")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Argument(help: "VM name")
	var name: String

	@Option(help: "Number of seconds to wait for a potential VM booting")
	var wait: Int = 0

	mutating func validate() throws {
		Logger.setLevel(self.logLevel)
	}

	mutating func run() throws {
		Logger.appendNewLine(try WaitIPHandler.waitIP(name: self.name, wait: self.wait, asSystem: false))
	}
}
