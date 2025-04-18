import ArgumentParser
import Virtualization
import GRPCLib
import Logging

struct Configure: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Reconfigure VM")

	@OptionGroup var common: CommonOptions
	@OptionGroup var options: ConfigureOptions
	
	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)
		try self.options.validate()
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try ConfigureHandler.configure(name: self.options.name, options: options, asSystem: self.common.asSystem)))
	}
}
