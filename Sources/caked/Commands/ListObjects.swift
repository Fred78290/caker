import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import Logging
import CakedLib

struct ListObjects: AsyncParsableCommand {
	static let configuration = CommandConfiguration(commandName: "list", abstract: "List all VMs")

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@Flag(help: "List all VMs and cached objects")
	var all: Bool = false

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() async throws {
		Logger.appendNewLine(self.common.format.render(try CakedLib.ListHandler.list(vmonly: !all, runMode: self.common.runMode)))
	}
}
