import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC
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
		Logger.appendNewLine(self.common.format.render(try LogoutHandler.logout(host: self.host, direct: true, asSystem: self.common.asSystem)))
	}
}
