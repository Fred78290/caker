import ArgumentParser
import GRPCLib
import Logging

struct Build: AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Create a linux VM and initialize it with cloud-init")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@OptionGroup var options: GRPCLib.BuildOptions

	func validate() throws {
		Logger.setLevel(self.logLevel)

		try self.options.validate()

		if StorageLocation(asSystem: false).exists(self.options.name) {
			throw ValidationError("\(self.options.name) already exists")
		}
	}

	mutating func run() async throws {
		try await BuildHandler.build(name: self.options.name, options: self.options, asSystem: false)
	}
}
