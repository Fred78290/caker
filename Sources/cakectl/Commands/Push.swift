import ArgumentParser
import Compression
import Dispatch
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Push: GrpcParsableCommand {
	static let configuration = PushOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Push options")
	var push: PushOptions

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.push(Caked_PushRequest(command: self), callOptions: callOptions).response.wait().oci.push)
	}
}
