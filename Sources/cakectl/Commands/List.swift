import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib

fileprivate struct VMInfo: Encodable {
	let Source: String
	let Name: String
	let Disk: Int
	let Size: Int
	let SizeOnDisk: Int
	let Running: Bool
	let State: String
}

struct List: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "List created VMs")

	@Option(help: ArgumentHelp("Only display VMs from the specified source (e.g. --source local, --source oci)."))
	var source: String?

	@Option(help: "Output format: text or json")
	var format: Format = .text

	@Flag(name: [.short, .long], help: ArgumentHelp("Only display VM names."))
	var quiet: Bool = false

	mutating func run() async throws {
		throw GrpcError(code: 0, reason: "nothing here")
	}

	func run(client: Caked_ServiceNIOClient, arguments: [String]) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "list", arguments: arguments)).response.wait()
	}
}
