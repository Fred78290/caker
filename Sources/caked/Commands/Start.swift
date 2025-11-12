import ArgumentParser
import CakedLib
import Logging
import NIOPortForwarding

struct Start: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Run linux VM in background")

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@Flag(help: ArgumentHelp("Launch vm in foreground", discussion: "This option allow display window of running vm to debug it", visibility: .hidden))
	var foreground: Bool = false

	@Argument(help: "VM name")
	var name: String

	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
	var waitIPTimeout = 180

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		let location = try StorageLocation(runMode: self.common.runMode).find(name)
		let config = try location.config()

		Logger.appendNewLine(self.common.format.render(CakedLib.StartHandler.startVM(location: location, config: config, waitIPTimeout: waitIPTimeout, startMode: self.foreground ? .foreground : .background, runMode: self.common.runMode)))
	}
}
