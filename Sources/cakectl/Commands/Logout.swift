import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI

struct Logout: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Logout from a registry")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Argument(help: "Host")
	var host: String

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.logout(Caked_LogoutRequest(command: self), callOptions: callOptions).response.wait().tart.message
	}
}
