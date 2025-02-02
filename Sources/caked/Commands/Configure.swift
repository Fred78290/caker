import ArgumentParser
import Virtualization
import GRPCLib
import Logging

struct Configure: AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Reconfigure VM")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@OptionGroup var options: ConfigureOptions
	
	mutating func validate() throws {
		Logger.setLevel(self.logLevel)
	}

	mutating func run() async throws {
		try ConfigureHandler.configure(name: self.options.name, options: options, asSystem: false)
	}
}
