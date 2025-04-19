import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct WaitIP: GrpcParsableCommand {
	static let configuration = WaitIPOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Wait ip options")
	var waitip: WaitIPOptions

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.waitIP(Caked_WaitIPRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.message
	}
}
