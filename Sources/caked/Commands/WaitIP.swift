import ArgumentParser

struct WaitIP: ParsableCommand {
	static var configuration = CommandConfiguration(commandName: "waitip", abstract: "Run linux VM in background")

	@Argument(help: "VM name")
	var name: String

	@Option(help: "Number of seconds to wait for a potential VM booting")
	var wait: Int = 0

	mutating func run() throws {
		Logger.appendNewLine(try WaitIPHandler.waitIP(name: self.name, wait: self.wait, asSystem: false))
	}
}
