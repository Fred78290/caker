import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import TextTable
import Logging

struct List: AsyncParsableCommand {
	static let configuration = CommandConfiguration(abstract: "List all VMs")

	@Option(name: .shortAndLong, help: "Output format")
	var format: Format = .text

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Flag(help: "List only VMs")
	var vmonly: Bool = false

	func validate() throws {
		Logger.setLevel(self.logLevel)
	}

	func run() async throws {
		Logger.appendNewLine(self.format.render(try ListHandler.list(vmonly: vmonly, asSystem: false)))
	}
}
