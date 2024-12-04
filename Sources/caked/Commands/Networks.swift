import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC

struct Networks: AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: """
	List host network devices (physical interfaces, virtual switches, bridges) available
	to integrate with using the `--bridged` switch to the `launch` command
""")

	@Option(help: "Output format: text or json")
	var format: Format = .text

	mutating func run() async throws {
		Logger.appendNewLine(self.format.renderList(NetworksHandler.networks()))
	}
}