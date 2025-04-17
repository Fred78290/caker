import ArgumentParser
import Foundation
import NIO
import GRPC
import GRPCLib
import CakeAgentLib
import Logging
import TextTable

struct Infos: CakeAgentAsyncParsableCommand {
	static let configuration: CommandConfiguration = CommandConfiguration(commandName: "infos", abstract: "Get info for VM")

	@Argument(help: "VM name")
	var name: String

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Option(name: .shortAndLong, help: "Output format: text or json")
	var format: Format = .text

	@OptionGroup(title: "override client agent options", visibility: .hidden)
	var options: CakeAgentClientOptions

	@Flag(name: [.customLong("system"), .customShort("s")], help: "Run caked as system agent, need sudo")
	var asSystem: Bool = false

	var createVM: Bool = false

	var retries: GRPC.ConnectionBackoff.Retries {
		.unlimited
	}

	var callOptions: GRPC.CallOptions? {
		CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(options.timeout)))
	}

	mutating func validate() throws {
		try self.validateOptions()
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		Logger.appendNewLine(self.format.render(try InfosHandler.infos(name: self.name, asSystem: self.asSystem, client: CakeAgentHelper(on: on, client: client), callOptions: callOptions)))
	}
}
