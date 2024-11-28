import ArgumentParser
import Foundation
import GRPCLib

struct Start: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Launch a linux VM create in background")

	@Argument(help: "VM name")
	var name: String

	func run(client: Caked_ServiceNIOClient, arguments: [String]) throws -> Caked_Reply {
		return try client.start(Caked_StartRequest(command: self)).response.wait()
	}
}
