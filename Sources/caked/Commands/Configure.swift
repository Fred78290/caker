import ArgumentParser
import Virtualization
import GRPCLib

struct Configure: AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Reconfigure VM")

	@OptionGroup var options: ConfigureOptions
	
	mutating func run() async throws {
		try await ConfigureHandler.configure(name: self.options.name, options: options, asSystem: false)
	}
}
