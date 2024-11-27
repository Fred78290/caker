import ArgumentParser
import Foundation
import GRPCLib

struct Suspend: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "suspend", abstract: "Suspend a VM")

	@Argument(help: "VM name")
	var name: String

	func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) throws -> Tarthelper_TartReply {
		return try client.tartCommand(Tarthelper_TartCommandRequest(command: "suspend", arguments: arguments)).response.wait()
	}
}
