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

	@Option(help: "Output format: text or json")
	var format: Format = .text

	@OptionGroup
	var options: CakeAgentClientOptions

	@Flag(help: .hidden)
	var foreground: Bool = false

	@Option(help:"Maximum of seconds to getting IP")
	var waitIPTimeout = 180

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		try await startVM(on: on.next(), waitIPTimeout: self.waitIPTimeout, foreground: self.foreground)

		let infos = try CakeAgentHelper(on: on, client: client).info(callOptions: callOptions)

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
