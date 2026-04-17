import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO

struct Infos: CakeAgentParsableCommand {
	static let configuration: CommandConfiguration = CommandConfiguration(commandName: "infos", abstract: String(localized: "Get info for VM"))

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@OptionGroup(title: String(localized: "override client agent options"), visibility: .hidden)
	var options: CakeAgentClientOptions

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	var name: String

	var createVM: Bool = false

	var logLevel: Logger.LogLevel {
		self.common.logLevel
	}

	var runMode: Utils.RunMode {
		self.common.runMode
	}

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		try self.validateOptions(runMode: self.common.runMode)
	}

	func run(on: EventLoopGroup, helper: CakeAgentHelper, callOptions: CallOptions?) {
		do {
			let result = try CakedLib.InfosHandler.infos(name: self.name, runMode: self.common.runMode, client: helper, callOptions: callOptions)
			
			Logger.appendNewLine(self.common.format.render(result.infos))
		} catch {
			Logger.appendNewLine(self.common.format.render(error.reason))
		}
	}
}
