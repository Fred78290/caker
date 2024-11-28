import ArgumentParser
import Foundation
import GRPCLib

struct Suspend: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "suspend", abstract: "Suspend a VM")

	@Argument(help: "VM name")
	var name: String

	func run(client: Caked_ServiceNIOClient, arguments: [String]) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "suspend", arguments: arguments)).response.wait()
	}
}
