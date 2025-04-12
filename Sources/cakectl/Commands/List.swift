import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC

struct List: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "List created VMs")

	@OptionGroup var options: Client.Options

	@Flag(help: ArgumentHelp("Only display VMs", valueName: "vmonly"))
	var vmonly: Bool = false

	@Option(name: .shortAndLong, help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.list(Caked_ListRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.list)
	}
}
