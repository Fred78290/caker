import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import TextTable
import Logging

struct List: AsyncParsableCommand {
	static let configuration = CommandConfiguration(abstract: "List all VMs")

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@Flag(help: "List all VMs and cached objects")
	var all: Bool = false

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() async throws {
		Logger.appendNewLine(self.common.format.render(try ListHandler.list(vmonly: !all, asSystem: self.common.asSystem)))
	}
}
