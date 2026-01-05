import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI
import CakeAgentLib

struct Login: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Login to a registry")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Login options")
	var login: LoginOptions

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run() async throws {
		throw GrpcError(code: 0, reason: "nothing here")
	}

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.login(Caked_LoginRequest(command: self), callOptions: callOptions).response.wait().oci.login)
	}
}
