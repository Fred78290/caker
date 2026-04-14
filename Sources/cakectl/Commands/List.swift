import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI
import CakeAgentLib

struct List: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: String(localized: "List created VMs"), aliases: ["ls"])

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Flag(help: ArgumentHelp(String(localized: "List all VMs and cached objects")))
	var all: Bool = false

	@Flag(help: ArgumentHelp(String(localized: "Include VM configuration in the output")))
	var includeConfig: Bool = false

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.list(Caked_ListRequest(command: self), callOptions: callOptions).response.wait().vms.list

		if result.success {
			return self.options.format.render(result.infos)
		} else {
			return self.options.format.render(result.reason)
		}
	}
}
