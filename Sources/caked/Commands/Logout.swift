import ArgumentParser
import CakedLib
import Dispatch
import GRPC
import GRPCLib
import CakeAgentLib

struct Logout: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: String(localized: "Logout from a registry"))

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Argument(help: ArgumentHelp(String(localized: "host")))
	var host: String

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(CakedLib.LogoutHandler.logout(host: self.host, direct: true, runMode: self.common.runMode)))
	}
}
