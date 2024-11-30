import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Create: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Create a VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String

	@Option(help: ArgumentHelp("create a macOS VM using path to the IPSW file or URL (or \"latest\", to fetch the latest supported IPSW automatically)", valueName: "path"))
	var fromIPSW: String?

	@Flag(help: "create a Linux VM")
	var linux: Bool = false

	@Option(help: ArgumentHelp("Disk size in GB"))
	var diskSize: UInt16 = 50

	mutating func run() async throws {
		throw GrpcError(code: 0, reason: "nothing here")
	}

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "create", arguments: arguments), callOptions: callOptions).response.wait()
	}
}
