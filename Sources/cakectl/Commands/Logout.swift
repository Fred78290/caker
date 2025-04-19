import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC

struct Logout: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Logout from a registry")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Argument(help: "Host")
	var host: String

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.logout(Caked_LogoutRequest(command: self), callOptions: callOptions).response.wait().successfull().tart.message
	}
}
