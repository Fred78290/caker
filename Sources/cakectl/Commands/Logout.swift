import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC

struct Logout: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Logout from a registry")

	@OptionGroup var options: Client.Options

	@Argument(help: "host")
	var host: String

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.logout(Caked_LogoutRequest(command: self), callOptions: callOptions).response.wait()
	}
}
