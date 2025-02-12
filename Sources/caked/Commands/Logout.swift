import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC
import Logging

struct Logout: AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Logout from a registry")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Argument(help: "host")
	var host: String

	mutating func run() async throws {
		Logger.setLevel(self.logLevel)

		print(try LogoutHandler.logout(host: self.host, direct: true))
	}
}
