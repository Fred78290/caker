import ArgumentParser
import Logging
import GRPCLib

struct Stop: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Stop VM")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Option(name: .shortAndLong, help: "Output format")
	var format: Format = .text

	@Argument(help: "VM names to stop")
	var names: [String] = []

	@Flag(help: "Force stop")
	var force: Bool = false

	@Flag(name: [.short, .long], help: "Stop all VM")
	var all: Bool = false

	func validate() throws {
		Logger.setLevel(self.logLevel)

		if all {
			if !names.isEmpty {
				throw ValidationError("You cannot specify both --all and VM names.")
			}
		} else if names.isEmpty {
			throw ValidationError("You must specify at least one VM name.")
		}
	}

	func run() throws {
		Logger.appendNewLine(self.format.render(try StopHandler.stopVMs(all: self.all, names: self.names, force: self.force, asSystem: false)))
	}
}
