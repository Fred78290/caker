import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import TextTable

struct List: AsyncParsableCommand {
	static let configuration = CommandConfiguration(abstract: "List all VMs")

	@Option(name: .shortAndLong, help: "Output format")
	var format: Format = .text

	@Flag(help: "List only VMs")
	var vmonly: Bool = false

	func run() async throws {
		Logger.appendNewLine(self.format.render(try ListHandler.list(vmonly: vmonly, asSystem: false)))
	}
}
