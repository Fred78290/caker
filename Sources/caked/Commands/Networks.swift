import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC
import Logging
import TextTable

struct Networks: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Manage host network devices",
	                                                subcommands: [Networks.List.self, Networks.Start.self, Networks.Stop.self])

	struct Start: AsyncParsableCommand {
		static var configuration = CommandConfiguration(abstract: "Start VMNet network device")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@OptionGroup var options: NetworksHandler.VMNetOptions

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		func run() async throws {
			try await NetworksHandler.start(options: self.options)
		}
	}

	struct Stop: ParsableCommand {
		static var configuration = CommandConfiguration(abstract: "Stop VMNet network device")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Option(name: [.customLong("interface-id")], help: ArgumentHelp("vmnet interface ID\n", discussion: "stop vmnet interface with the specified or created ID by start command"))
		var interfaceID = UUID().uuidString

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(try NetworksHandler.stop(interfaceID: self.interfaceID))
		}
	}

	struct List: ParsableCommand {
		static var configuration = CommandConfiguration(abstract:
			"""
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
}