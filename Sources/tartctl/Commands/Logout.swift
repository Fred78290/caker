import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib

struct Logout: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Logout from a registry")

	@Argument(help: "host")
	var host: String

	func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) throws -> Tarthelper_TartReply {
		return try client.tartCommand(Tarthelper_TartCommandRequest(command: "logout", arguments: arguments)).response.wait()
	}
}
