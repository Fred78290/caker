import ArgumentParser

struct Stop: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Run linux VM in background")

	@Flag(help: "Force stop")
	var force: Bool = false

	@Argument(help: "VM name")
	var name: String

	mutating func run() throws {
		Logger.appendNewLine(try StopHandler.stopVM(name: self.name, force: self.force, asSystem: false))
	}
}
