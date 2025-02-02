import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC
import Logging
import TextTable

struct Networks: AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: """
List host network devices (physical interfaces, virtual switches, bridges) available
to integrate with using the `--bridged` switch to the `launch` command
""")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Option(help: "Output format: text or json")
	var format: Format = .text

	mutating func validate() throws {
		Logger.setLevel(self.logLevel)
	}

	mutating func run() async throws {
		Logger.appendNewLine(self.format.renderList(style: Style.grid, uppercased: true, NetworksHandler.networks()))
	}
}