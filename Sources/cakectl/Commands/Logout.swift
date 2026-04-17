import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI
import CakeAgentLib

struct Logout: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: String(localized: "Logout from a registry"))

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Argument(help: ArgumentHelp(String(localized: "Host")))
	var host: String

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.options.format.render(try client.logout(Caked_LogoutRequest(command: self), callOptions: callOptions).response.wait().oci.logout)
	}
}
