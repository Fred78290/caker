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

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@Argument(help: "VM name")
	var name: String

	@OptionGroup(title: "override client agent options", visibility: .hidden)
	var options: CakeAgentClientOptions

	var createVM: Bool = false

	var logLevel: Logging.Logger.Level {
		self.common.logLevel
	}

	var asSystem: Bool {
		self.common.asSystem
	}

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		try self.validateOptions(asSystem: self.common.asSystem)
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		Logger.appendNewLine(self.common.format.render(try InfosHandler.infos(name: self.name, asSystem: self.common.asSystem, client: CakeAgentHelper(on: on, client: client), callOptions: callOptions)))
	}
}
