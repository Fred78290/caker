import ArgumentParser
import NIOPortForwarding
import Logging

struct Start: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Run linux VM in background")

	@OptionGroup var common: CommonOptions

	@Flag(help: .hidden)
	var foreground: Bool = false

	@Argument(help: "VM name")
	var name: String

	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
	var waitIPTimeout = 180

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		let vmLocation = try StorageLocation(asSystem: self.common.asSystem).find(name)
		let config = try vmLocation.config()

		Logger.appendNewLine(self.common.format.render(try StartHandler.startVM(vmLocation: vmLocation, config: config, waitIPTimeout: waitIPTimeout, startMode: self.foreground ? .foreground : .background, asSystem: self.common.asSystem)))
	}
}
