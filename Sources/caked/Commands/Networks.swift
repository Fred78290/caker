import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC
import Logging
import TextTable

struct Networks: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: """
List host network devices (physical interfaces, virtual switches, bridges) available
to integrate with using the `--network` switch to the `launch` command
""")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Option(name: .shortAndLong, help: "Output format: text or json")
	var format: Format = .text

	mutating func validate() throws {
		Logger.setLevel(self.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.format.renderList(style: Style.grid, uppercased: true, NetworksHandler.networks()))
	}
}