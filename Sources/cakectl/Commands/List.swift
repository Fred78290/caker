import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC

struct List: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "List created VMs")

	@OptionGroup var options: Client.Options

	@Flag(help: ArgumentHelp("Only display VMs", valueName: "vmonly"))
	var vmonly: Bool = false

	@Option(name: .shortAndLong, help: "Output format: text or json")
	var format: Format = .text

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.list(Caked_ListRequest(command: self), callOptions: callOptions).response.wait()
	}
}
