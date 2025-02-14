import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import TextTable

struct List: AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: "List all VMs")

	@Option(name: .shortAndLong, help: "Output format")
	var format: Format = .text

	@Flag(help: "List only VMs")
	var vmonly: Bool = false

	mutating func run() async throws {
		print(try ListHandler.listVM(vmonly: vmonly, format: format, asSystem: false))
	}
}