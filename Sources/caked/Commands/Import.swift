import Foundation
import ArgumentParser
import CakedLib
import GRPCLib
import Logging

struct Import: AsyncParsableCommand {
	static var configuration = CommandConfiguration(
		commandName: "import",
		abstract: "Import a Cakefile from a file or URL."
	)

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@Argument(help: "The path to the Cakefile to import.")
	var from: CakedLib.ImportHandler.ImportSource
	
	@Argument(help: "The name of the VM to import.")
	var name: String

	@Argument(help: "The path to the source file or directory to import.")
	var source: String

	var logLevel: Logging.Logger.Level {
		self.common.logLevel
	}

	var runMode: Utils.RunMode {
		self.common.runMode
	}

	func run() async throws {
		let result = try await ImportHandler.importVM(from: from, name: name, source: source, runMode: .user)
	}
}
