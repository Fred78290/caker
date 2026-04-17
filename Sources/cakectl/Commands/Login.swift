import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI
import CakeAgentLib

struct Login: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: String(localized: "Login to a registry"))

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Login options"))
	var login: LoginOptions

	func run() async throws {
		throw GrpcError(code: 0, reason: String(localized: "nothing here"))
	}

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.options.format.render(try client.login(Caked_LoginRequest(command: self), callOptions: callOptions).response.wait().oci.login)
	}
}
