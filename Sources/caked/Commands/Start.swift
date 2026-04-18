import ArgumentParser
import CakedLib
import CakeAgentLib
import NIOPortForwarding

struct Start: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: String(localized: "Start an existing VM"))

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Flag(help: ArgumentHelp(String(localized: "Launch vm in foreground"), discussion: String(localized: "This option allow display window of running vm to debug it"), visibility: .hidden))
	var foreground: Bool = false

	@Flag(name: [.customLong("recovery")], help: ArgumentHelp(String(localized: "Launch vm in recovery mode"), discussion: String(localized: "This option allows starting the MacOS VM in recovery mode")))
	var recoveryMode: Bool = false

	@Option(help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout = 180

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	var name: String

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		let location = try StorageLocation(runMode: self.common.runMode).find(name)

		Logger.appendNewLine(self.common.format.render(CakedLib.StartHandler.startVM(location: location, screenSize: nil, vncPassword: nil, vncPort: nil, waitIPTimeout: waitIPTimeout, startMode: self.foreground ? .foreground : .background, gcd: false, recoveryMode: recoveryMode, runMode: self.common.runMode)))
	}
}
