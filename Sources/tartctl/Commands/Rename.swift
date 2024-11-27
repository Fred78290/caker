import ArgumentParser
import Foundation
import GRPCLib

struct Rename: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Rename a local VM")

	@Argument(help: "VM name")
	var name: String

	@Argument(help: "new VM name")
	var newName: String

	func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) throws -> Tarthelper_TartReply {
		return try client.tartCommand(Tarthelper_TartCommandRequest(command: "rename", arguments: arguments)).response.wait()
	}
}
