import ArgumentParser
import Compression
import Dispatch
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Push: GrpcParsableCommand {
	static let configuration = PushOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Push options"))
	var push: PushOptions

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.options.format.render(try client.push(Caked_PushRequest(command: self), callOptions: callOptions).response.wait().oci.push)
	}
}
