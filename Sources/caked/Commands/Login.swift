import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC
import Logging

struct Login: AsyncParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Login to a registry")

	@OptionGroup var common: CommonOptions

	@Argument(help: "host")
	var host: String

	@Option(help: "username")
	var username: String?

	@Option(help: "password")
	var password: String?

	@Flag(help: "password from stdin")
	var passwordStdin: Bool = false

	@Flag(help: "connect to the OCI registry via insecure HTTP protocol")
	var insecure: Bool = false

	@Flag(help: "skip validation of the registry's credentials before logging-in")
	var noValidate: Bool = false

	func validate() throws {
		let usernameProvided = username != nil
		let passwordProvided = password != nil

		Logger.setLevel(self.common.logLevel)

		if !usernameProvided {
			throw ValidationError("--username is required")
		}

		if passwordProvided && passwordStdin {
			throw ValidationError("specify one of --password-stdin or --password not both")
		}

		if usernameProvided != passwordProvided && usernameProvided != passwordStdin {
			throw ValidationError("both --username and --password-stdin or --password are required")
		}
	}

	mutating func run() async throws {
		if self.passwordStdin {
			self.password = readLine(strippingNewline: true)
		}

		Logger.appendNewLine(self.common.format.render(try LoginHandler.login(host: host, username: self.username!, password: self.password!, insecure: self.insecure, noValidate: self.noValidate, direct: true, asSystem: self.common.asSystem)))
	}
}
