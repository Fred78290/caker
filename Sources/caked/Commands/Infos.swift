import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import Logging
import NIO

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

	var runMode: Utils.RunMode {
		self.common.runMode
	}

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		try self.validateOptions(runMode: self.common.runMode)
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async {
		let result: VirtualMachineStatusReply = CakedLib.InfosHandler.infos(name: self.name, runMode: self.common.runMode, client: CakeAgentHelper(on: on, client: client), callOptions: callOptions)

		if result.success {
			Logger.appendNewLine(self.common.format.render(result.status))
		} else {
			Logger.appendNewLine(self.common.format.render(result.reason))
		}
	}
}
