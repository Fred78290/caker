import ArgumentParser
import Foundation
import GRPCLib

struct Launch : AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Create a linux VM, initialize it with cloud-init and launch in background")

	@OptionGroup var options: GRPCLib.BuildOptions

	@Flag(help: .hidden)
	var foreground: Bool = false

	func validate() throws {
		try self.options.validate()

		if StorageLocation(asSystem: false).exists(self.options.name) {
			throw ValidationError("\(self.options.name) already exists")
		}
	}

	mutating func run() async throws {
		let runningIP = try await LaunchHandler.buildAndLaunchVM(asSystem: false, options: options, foreground: self.foreground)

		Logger.appendNewLine("launched \(options.name) with IP: \(runningIP)")
	}
}
