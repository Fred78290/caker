import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Stop: GrpcParsableCommand {
	static let configuration = StopOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Global options")
	var stop: StopOptions

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.stop(Caked_StopRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.stop)
	}
}
