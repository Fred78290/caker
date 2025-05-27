import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI

struct List: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "List created VMs")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Flag(help: "List all VMs and cached objects")
	var all: Bool = false

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.list(Caked_ListRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.list)
	}
}
