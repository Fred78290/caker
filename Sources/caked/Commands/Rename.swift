import ArgumentParser

public struct Rename: ParsableCommand {
	public init() {}
	
	@Argument(help: "VM name")
	var name: String

	@Argument(help: "New VM name")
	var newname: String

	public mutating func run() throws {
		print(try RenameHandler.rename(oldname: name, newname: newname))
	}
}