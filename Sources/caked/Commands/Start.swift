import ArgumentParser

struct Start: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Run linux VM in background")

	@Flag(help: ArgumentHelp("Enable nested virtualization if possible"))
	var nested: Bool = false

	@Flag(help: "VM name")
	var foreground: Bool = false

	@Argument(help: "VM name")
	var name: String

	mutating func run() throws {
		let vmLocation = try StorageLocation(asSystem: false).find(name)

		try StartHandler.startVM(vmLocation: vmLocation, nested: self.nested, foreground: self.foreground)
	}
}
