import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct WaitIP: GrpcParsableCommand {
	static let configuration = CommandConfiguration(commandName: "waitip", abstract: "Wait IP for running VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String

	@Option(help: ArgumentHelp("Time to wait for a potential VM booting", valueName: "seconds"))
	var wait: UInt16 = 0

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.waitIP(Caked_WaitIPRequest(command: self), callOptions: callOptions).response.wait()
	}
}
