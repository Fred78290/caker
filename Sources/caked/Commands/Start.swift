import ArgumentParser
import NIOPortForwarding

struct Start: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Run linux VM in background")

	@Flag(help: .hidden)
	var foreground: Bool = false

	@Argument(help: "VM name")
	var name: String

	@Option(help:"Maximum of seconds to getting IP")
	var waitIPTimeout = 180

	mutating func run() throws {
		let vmLocation = try StorageLocation(asSystem: false).find(name)

		Logger.appendNewLine(try StartHandler.startVM(vmLocation: vmLocation, waitIPTimeout: waitIPTimeout, foreground: self.foreground))
	}
}
