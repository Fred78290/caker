import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib

struct Logout: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Logout from a registry")

	@Argument(help: "host")
	var host: String

	func run(client: Caked_ServiceNIOClient, arguments: [String]) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "logout", arguments: arguments)).response.wait()
	}
}
