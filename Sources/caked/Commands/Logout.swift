import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC
import Logging

struct Logout: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Logout from a registry")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Argument(help: "host")
	var host: String

	func run() throws {
		Logger.setLevel(self.logLevel)

		Logger.appendNewLine(try LogoutHandler.logout(host: self.host, direct: true))
	}
}
