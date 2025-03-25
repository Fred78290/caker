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
			try self.options.validate()
		}

		func run() async throws {
			try NetworksHandler.start(options: self.options)
		}
	}

	struct Stop: ParsableCommand {
		static var configuration = CommandConfiguration(abstract: "Stop VMNet network device")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Run caked as system agent, need sudo")
		var asSystem: Bool = false

		@Option(name: [.customLong("mode")], help: "vmnet mode")
		var mode = VMNetMode.host

		@Option(name: [.customLong("interface")], help: ArgumentHelp("interface\n", discussion: "interface used for --vmnet=bridged, e.g., \"en0\""))
		var networkInterface: String? = nil

		func validate() throws {
			Logger.setLevel(self.logLevel)

			runAsSystem = self.asSystem
			
			if self.mode == .bridged {
				if self.networkInterface == nil {
					throw ValidationError("interface is required for bridged mode")
				}
			}
		}

		func run() throws {
			Logger.appendNewLine(try NetworksHandler.stop(mode: self.mode, networkInterface: self.networkInterface, asSystem: self.asSystem))
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
