import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Stop: GrpcParsableCommand {
	static let configuration = CommandConfiguration(commandName: "stop", abstract: "Stop a VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM names to stop")
	var name: [String] = []

	@Option(name: .shortAndLong, help: "Force to stop")
	var force: Bool = false

	@Flag(name: .shortAndLong, help: "Stop all VM")
	var all: Bool = false

	@Option(name: .shortAndLong, help: "Output format: text or json")
	var format: Format = .text

	func validate() throws {
		if all {
			if !name.isEmpty {
				throw ValidationError("You cannot specify both --all and VM names.")
			}
		} else if name.isEmpty {
			throw ValidationError("You must specify at least one VM name.")
		}
	}

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.stop(Caked_StopRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.stop)
	}
}
