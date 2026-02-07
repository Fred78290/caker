import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct WaitIP: GrpcParsableCommand {
	static let configuration = WaitIPOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Wait ip options")
	var waitip: WaitIPOptions

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.waitIP(Caked_WaitIPRequest(command: self), callOptions: callOptions).response.wait().vms.waitip)
	}
}
