import ArgumentParser
import Logging

struct Rename: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Rename a VM")
	
	@Argument(help: "VM name")
	var name: String

	@Argument(help: "New VM name")
	var newname: String

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	func validate() throws {
		Logger.setLevel(self.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(try RenameHandler.rename(oldname: name, newname: newname))
	}
}
