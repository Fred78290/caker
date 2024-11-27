import ArgumentParser
import Foundation
import GRPCLib

struct Start: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Launch a linux VM create in background")

	@Argument(help: "VM name")
	var name: String

	func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) throws -> Tarthelper_TartReply {
		return try client.start(Tarthelper_StartRequest(command: self)).response.wait()
	}
}
