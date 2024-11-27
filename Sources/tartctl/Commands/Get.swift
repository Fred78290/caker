import ArgumentParser
import Foundation
import GRPCLib

enum Format: String, ExpressibleByArgument {
	case text, json
}

struct Get: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "get", abstract: "Get a VM's configuration")

	@Argument(help: "VM name.")
	var name: String

	@Option(help: "Output format: text or json")
	var format: Format = .text

	mutating func run() async throws {
		throw GrpcError(code: 0, reason: "nothing here")
	}

	func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) throws -> Tarthelper_TartReply {
		return try client.tartCommand(Tarthelper_TartCommandRequest(command: "get", arguments: arguments)).response.wait()
	}
}
