import ArgumentParser
import Foundation
import GRPCLib

struct Rename: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Rename a local VM")

	@Argument(help: "VM name")
	var name: String

	@Argument(help: "new VM name")
	var newName: String

	func run(client: Caked_ServiceNIOClient, arguments: [String]) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "rename", arguments: arguments)).response.wait()
	}
}
