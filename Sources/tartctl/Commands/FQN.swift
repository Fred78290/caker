import ArgumentParser
import Foundation
import GRPCLib

struct FQN: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Get a fully-qualified VM name", shouldDisplay: false)

	@Argument(help: "VM name")
	var name: String

	func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) throws -> Tarthelper_TartReply {
		return try client.tartCommand(Tarthelper_TartCommandRequest(command: "fqn", arguments: arguments)).response.wait()
	}
}
