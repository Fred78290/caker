import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC

struct List: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "List created VMs")

	@OptionGroup var options: Client.Options

	@Option(help: ArgumentHelp("Only display VMs from the specified source (e.g. --source local, --source oci)."))
	var source: String?

	@Option(help: "Output format: text or json")
	var format: Format = .text

	@Flag(name: [.short, .long], help: ArgumentHelp("Only display VM names."))
	var quiet: Bool = false

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "list", arguments: arguments), callOptions: callOptions).response.wait()
	}
}
