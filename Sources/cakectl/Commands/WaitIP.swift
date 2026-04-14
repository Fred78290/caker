import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct WaitIP: GrpcParsableCommand {
	static let configuration = WaitIPOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Wait ip options"))
	var waitip: WaitIPOptions

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.options.format.render(try client.waitIP(Caked_WaitIPRequest(command: self), callOptions: callOptions).response.wait().vms.waitip)
	}
}
