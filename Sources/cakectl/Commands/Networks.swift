import Foundation
import ArgumentParser
import GRPC
import GRPCLib

struct Networks: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: """
List host network devices (physical interfaces, virtual switches, bridges) available
to integrate with using the `--bridged` switch to the `launch` command
""")

	@OptionGroup var options: Client.Options

	@Option(name: .shortAndLong, help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait()
	}
}
