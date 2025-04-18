import ArgumentParser
import Logging

struct Rename: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Rename a VM")
	
	@OptionGroup var common: CommonOptions

	@Argument(help: "VM name")
	var name: String

	@Argument(help: "New VM name")
	var newname: String

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try RenameHandler.rename(oldname: name, newname: newname, asSystem: self.common.asSystem)))
	}
}
