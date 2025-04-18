import ArgumentParser
import GRPCLib
import Logging

struct Build: AsyncParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Create a linux VM and initialize it with cloud-init")

	@OptionGroup var common: CommonOptions
	@OptionGroup var options: GRPCLib.BuildOptions

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		try self.options.validate()

		if StorageLocation(asSystem: self.common.asSystem).exists(self.options.name) {
			throw ValidationError("\(self.options.name) already exists")
		}

		if options.sockets.first(where: { $0.sharedFileDescriptors != nil }) != nil {
			throw ValidationError("Shared file descriptors are not supported, use launch instead")
		}
	}

	func run() async throws {
		try await BuildHandler.build(name: self.options.name, options: self.options, asSystem: self.common.asSystem)
	}
}
