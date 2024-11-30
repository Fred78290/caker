import ArgumentParser

struct Start: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Run linux VM in background")

	@Flag(help: "VM name")
	var foreground: Bool = false

	@Argument(help: "VM name")
	var name: String

	mutating func run() throws {
		let vmLocation = try StorageLocation(asSystem: false).find(name)

		try StartHandler.startVM(vmLocation: vmLocation, foreground: self.foreground)
	}
}
