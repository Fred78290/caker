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

	@Flag(help: ArgumentHelp(String(localized: "Output format: text or json")))
	var format: Format = .text

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.push(Caked_PushRequest(command: self), callOptions: callOptions).response.wait().oci.push)
	}
}
