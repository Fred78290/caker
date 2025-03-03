import ArgumentParser
import Foundation
import NIO
import GRPC
import GRPCLib
import CakeAgentLib
import Logging
import TextTable

struct Infos: CakeAgentAsyncParsableCommand {
	static var configuration: CommandConfiguration = CommandConfiguration(commandName: "infos", abstract: "Get info for VM")

	@Argument(help: "VM name")
	var name: String

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Option(name: .shortAndLong, help: "Output format: text or json")
	var format: Format = .text

	@OptionGroup(title: "override client agent options", visibility: .hidden)
	var options: CakeAgentClientOptions

	@Flag(help: .hidden)
	var foreground: Bool = false

	@Option(help:"Maximum of seconds to getting infos")
	var waitIPTimeout = 180

    var createVM: Bool = false

    var retries: GRPC.ConnectionBackoff.Retries {
		.unlimited
	}

    var callOptions: GRPC.CallOptions? {
		CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(options.timeout)))
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		let vmLocation = try StorageLocation(asSystem: false).find(name)
		let config: CakeConfig = try vmLocation.config()
		var infos: InfoReply

		if vmLocation.status == .running {
			infos = try CakeAgentHelper(on: on, client: client).info(callOptions: callOptions)
		} else {
			
			infos = InfoReply.with {
				$0.osname = config.os.rawValue
				$0.status = .stopped
				$0.cpuCount = Int32(config.cpuCount)
				$0.memory = .with {
					$0.total = config.memorySize
				}

				if let runningIP = config.runningIP {
					$0.ipaddresses = [runningIP]
				}
			}
		}

		infos.name = name
		infos.mounts = config.mounts.map { $0.description }

		if format == .json {
			Logger.appendNewLine(format.renderSingle(style: Style.grid, uppercased: true, infos))
		} else {
			let reply = ShortInfoReply(name: name,
												ipaddresses: infos.ipaddresses,
												cpuCount: infos.cpuCount,
												memory: infos.memory?.total ?? 0)
			Logger.appendNewLine(format.renderSingle(style: Style.grid, uppercased: true, reply))
		}
	}
}
