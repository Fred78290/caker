import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Stop: GrpcParsableCommand {
	static let configuration = CommandConfiguration(commandName: "stop", abstract: "Stop a VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String

	@Option(name: [.short, .long], help: "Force to stop")
	var force: Bool = false

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.stop(Caked_StopRequest(command: self), callOptions: callOptions).response.wait()
	}
}
