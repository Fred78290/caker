import ArgumentParser
import Foundation
import GRPCLib

struct Stop: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "stop", abstract: "Stop a VM")

	@Argument(help: "VM name")
	var name: String

	@Option(name: [.short, .long], help: "Seconds to wait for graceful termination before forcefully terminating the VM")
	var timeout: UInt64 = 30

	func run(client: Caked_ServiceNIOClient, arguments: [String]) throws -> Caked_Reply {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: "stop", arguments: arguments)).response.wait()
	}
}
