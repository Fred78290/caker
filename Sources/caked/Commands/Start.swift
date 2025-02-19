import ArgumentParser
import NIOPortForwarding
import Logging

struct Start: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Run linux VM in background")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Flag(help: .hidden)
	var foreground: Bool = false

	@Argument(help: "VM name")
	var name: String

	@Option(help:"Maximum of seconds to getting IP")
	var waitIPTimeout = 180

	mutating func validate() throws {
		Logger.setLevel(self.logLevel)
	}

	mutating func run() async throws {
		let vmLocation = try StorageLocation(asSystem: false).find(name)
		let config = try vmLocation.config()

		Logger.appendNewLine(try StartHandler.startVM(vmLocation: vmLocation, config: config, waitIPTimeout: waitIPTimeout, startMode: self.foreground ? .foreground : .background))
	}
}
