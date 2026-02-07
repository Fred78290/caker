import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Build: GrpcParsableCommand {
	static let configuration = BuildOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Build VM options")
	var buildOptions: BuildOptions

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	mutating func validate() throws {
		try buildOptions.validate()

		if buildOptions.sockets.first(where: { $0.sharedFileDescriptors != nil }) != nil {
			throw ValidationError("Shared file descriptors are not supported, use caked launch instead")
		}
	}

	func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.build(Caked_BuildRequest(buildOptions: self.buildOptions), callOptions: callOptions).response.wait().vms.builded)
	}
}
