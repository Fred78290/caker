import ArgumentParser
import Logging
import GRPCLib

struct Stop: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Stop VM")

	@OptionGroup var common: CommonOptions

	@Argument(help: "VM names to stop")
	var names: [String] = []

	@Flag(help: "Force stop")
	var force: Bool = false

	@Flag(name: .shortAndLong, help: "Stop all VM")
	var all: Bool = false

	func validate() throws {
		Logger.setLevel(self.common.logLevel)

		if all {
			if !names.isEmpty {
				throw ValidationError("You cannot specify both --all and VM names.")
			}
		} else if names.isEmpty {
			throw ValidationError("You must specify at least one VM name.")
		}
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try StopHandler.stopVMs(all: self.all, names: self.names, force: self.force, asSystem: self.common.asSystem)))
	}
}
