import Foundation
import ArgumentParser
import CakedLib
import GRPCLib
import Logging

struct Import: ParsableCommand {
	static var configuration = CommandConfiguration(commandName: "convert",  abstract: "Import an external VM from a file or URL.")

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@Option(help: "Kind of virtual machine to convert from.")
	var from: CakedLib.ImportHandler.ImportSource = .vmdk
	
	@Argument(help: "The name virtual machine to convert from or abolsute path to the directory containing the VMs.")
	var source: String

	@Argument(help: "The name of the virtual machine to create.")
	var name: String

	var logLevel: Logging.Logger.Level {
		self.common.logLevel
	}

	var runMode: Utils.RunMode {
		self.common.runMode
	}

	func run() throws {
		let result = try ImportHandler.importVM(from: from, name: name, source: source, runMode: .user)

		if case let .error(err) = result.response {
			throw ServiceError(err.reason, err.code)
		} else {
			Logger.appendNewLine(self.common.format.render(result.vms.message))
		}
	}
}
