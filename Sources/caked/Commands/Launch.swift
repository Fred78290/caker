import ArgumentParser
import Foundation
import GRPCLib
import Logging

struct Launch : AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Create a linux VM, initialize it with cloud-init and launch in background")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@OptionGroup var options: GRPCLib.BuildOptions

	@Option(help:"Maximum of seconds to getting IP")
	var waitIPTimeout = 180

	@Flag(help: .hidden)
	var foreground: Bool = false

	mutating func validate() throws {
		Logger.setLevel(self.logLevel)

		try self.options.validate()

		if StorageLocation(asSystem: false).exists(self.options.name) {
			throw ValidationError("\(self.options.name) already exists")
		}
	}

	func run() async throws {
		let runningIP = try await LaunchHandler.buildAndLaunchVM(asSystem: false, options: options, waitIPTimeout: self.waitIPTimeout, foreground: self.foreground)

		Logger.info("launched \(options.name) with IP: \(runningIP)")
	}
}
