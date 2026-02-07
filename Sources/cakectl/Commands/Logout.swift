import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI
import CakeAgentLib

struct Logout: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Logout from a registry")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Argument(help: "Host")
	var host: String

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.logout(Caked_LogoutRequest(command: self), callOptions: callOptions).response.wait().oci.logout)
	}
}
