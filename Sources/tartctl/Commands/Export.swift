import ArgumentParser
import Foundation
import GRPCLib

struct Export: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Export VM to a compressed .tvm file")

	@Argument(help: "Source VM name.")
	var name: String

	@Argument(help: "Path to the destination file.")
	var path: String?

	func run(client: Tarthelper_ServiceNIOClient, arguments: [String]) throws -> Tarthelper_TartReply {
		return try client.tartCommand(Tarthelper_TartCommandRequest(command: "export", arguments: arguments)).response.wait()
	}
}
