import ArgumentParser
import GRPCLib
struct Build: AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Create a linux VM and initialize it with cloud-init")

	@OptionGroup var options: GRPCLib.BuildOptions

	func validate() throws {
		try self.options.validate()

		if StorageLocation(asSystem: false).exists(self.options.name) {
			throw ValidationError("\(self.options.name) already exists")
		}
	}

	mutating func run() async throws {
		try await BuildHandler.build(name: self.options.name, options: self.options, asSystem: false)
	}
}
