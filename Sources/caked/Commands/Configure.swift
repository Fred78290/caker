import ArgumentParser
import Virtualization
import GRPCLib
import Logging

struct Configure: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Reconfigure VM")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@OptionGroup var options: ConfigureOptions
	
	func validate() throws {
		Logger.setLevel(self.logLevel)
	}

	func run() throws {
		try ConfigureHandler.configure(name: self.options.name, options: options, asSystem: false)
	}
}
