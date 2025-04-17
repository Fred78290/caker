import ArgumentParser
import Logging

struct Stop: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Stop VM")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

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
		Logger.appendNewLine(try StopHandler.stopVMs(all: self.all, names: self.names, force: self.force, asSystem: false).joined(separator: "\n"))
	}
}
