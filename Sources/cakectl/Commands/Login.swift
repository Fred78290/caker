import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC

struct Login: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Login to a registry")

	@OptionGroup var options: Client.Options

	@Argument(help: "Host")
	var host: String

	@Option(help: "Username")
	var username: String?

	@Option(help: "Password")
	var password: String?

	@Flag(help: "Password from stdin")
	var passwordStdin: Bool = false

	@Flag(help: "Connect to the OCI registry via insecure HTTP protocol")
	var insecure: Bool = false

	@Flag(help: "Skip validation of the registry's credentials before logging-in")
	var noValidate: Bool = false

	mutating func run() async throws {
		throw GrpcError(code: 0, reason: "nothing here")
	}

	func validate() throws {
		let usernameProvided = username != nil
		let passwordProvided = password != nil

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

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.login(Caked_LoginRequest(command: self), callOptions: callOptions).response.wait().successfull().tart.message
	}
}
