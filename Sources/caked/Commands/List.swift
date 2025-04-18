import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import TextTable
import Logging

struct List: AsyncParsableCommand {
	static let configuration = CommandConfiguration(abstract: "List all VMs")

	@OptionGroup var common: CommonOptions

	@Flag(help: "List only VMs")
	var vmonly: Bool = false

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() async throws {
		Logger.appendNewLine(self.common.format.render(try ListHandler.list(vmonly: vmonly, asSystem: self.common.asSystem)))
	}
}
