import ArgumentParser
import Foundation
import GRPCLib
import Logging

struct Launch : AsyncParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Create a linux VM, initialize it with cloud-init and launch in background")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@OptionGroup var options: GRPCLib.BuildOptions

	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
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
		Logger.appendNewLine(try await LaunchHandler.buildAndLaunchVM(asSystem: false, options: options, waitIPTimeout: self.waitIPTimeout, startMode: self.foreground ? .foreground : .background))
	}
}
