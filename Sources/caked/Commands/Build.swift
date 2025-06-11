import ArgumentParser
import GRPCLib
import Logging

struct Build: AsyncParsableCommand {
	static let configuration = BuildOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Build VM options")
	var options: BuildOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)

		if StorageLocation(runMode: self.common.runMode).exists(self.options.name) {
			throw ValidationError("\(self.options.name) already exists")
		}

		if self.options.sockets.first(where: { $0.sharedFileDescriptors != nil }) != nil {
			throw ValidationError("Shared file descriptors are not supported, use launch instead")
		}
	}

	func run() async throws {
		try await BuildHandler.build(name: self.options.name, options: self.options, runMode: self.common.runMode)
	}
}
