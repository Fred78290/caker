import ArgumentParser
import Foundation
import GRPCLib
import Logging

struct Launch: AsyncParsableCommand {
	static let configuration = BuildOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Build VM options")
	var options: BuildOptions

	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
	var waitIPTimeout = 180

	@Flag(help: ArgumentHelp("Launch vm in foreground", discussion: "This option allow display window of running vm to debug it", visibility: .hidden))
	var foreground: Bool = false

	func validate() throws {
		Logger.setLevel(self.common.logLevel)

		if StorageLocation(asSystem: self.common.asSystem).exists(self.options.name) {
			throw ValidationError("\(self.options.name) already exists")
		}
	}

	func run() async throws {
		Logger.appendNewLine(self.common.format.render(try await LaunchHandler.buildAndLaunchVM(asSystem: self.common.asSystem, options: options, waitIPTimeout: self.waitIPTimeout, startMode: self.foreground ? .foreground : .background)))
	}
}
