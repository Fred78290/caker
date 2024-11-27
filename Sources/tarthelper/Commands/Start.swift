import ArgumentParser

struct Start: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Run linux VM in background")

	@Argument(help: "VM name")
	var name: String

	func run() throws {
		let vmLocation = try StorageLocation(asSystem: false).find(name)

		try StartHandler.startVM(vmLocation: vmLocation)
	}
}
