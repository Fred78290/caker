import ArgumentParser
import GRPCLib
import Logging

struct Rename: ParsableCommand {
	static let configuration = RenameOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Rename options")
	var rename: RenameOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try RenameHandler.rename(oldname: self.rename.name, newname: self.rename.newName, asSystem: self.common.asSystem)))
	}
}
