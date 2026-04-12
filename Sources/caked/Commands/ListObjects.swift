import ArgumentParser
import CakedLib
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct ListObjects: AsyncParsableCommand {
	static let configuration = CommandConfiguration(commandName: "list", abstract: String(localized: "List all VMs"), aliases: ["ls"])

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Flag(help: ArgumentHelp(String(localized: "List all VMs and cached objects")))
	var all: Bool = false

	@Flag(help: ArgumentHelp(String(localized: "Include VM configuration in the output")))
	var includeConfig: Bool = false

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() async throws {
		let result = CakedLib.ListHandler.list(vmonly: !all, includeConfig: includeConfig, runMode: self.common.runMode)

		if result.success {
			Logger.appendNewLine(self.common.format.render(result.infos))
		} else {
			Logger.appendNewLine(self.common.format.render(result.reason))
		}
	}
}
