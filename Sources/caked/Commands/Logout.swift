import ArgumentParser
import CakedLib
import Dispatch
import GRPC
import GRPCLib
import Logging

struct Logout: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Logout from a registry")

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@Argument(help: "host")
	var host: String

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try CakedLib.LogoutHandler.logout(host: self.host, direct: true, runMode: self.common.runMode)))
	}
}
