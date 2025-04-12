import ArgumentParser

struct Rename: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Rename a VM")
	
	@Argument(help: "VM name")
	var name: String

	@Argument(help: "New VM name")
	var newname: String

	func run() throws {
		Logger.appendNewLine(try RenameHandler.rename(oldname: name, newname: newname))
	}
}
