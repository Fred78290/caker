import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Build: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Create a linux VM and initialize it with cloud-init")

	@OptionGroup var options: Client.Options
	@OptionGroup var buildOptions: GRPCLib.BuildOptions

	mutating func validate() throws {
		try buildOptions.validate()

		if buildOptions.sockets.first(where: { $0.sharedFileDescriptors != nil }) != nil {
			throw ValidationError("Shared file descriptors are not supported, use caked launch instead")
		}
	}

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.build(Caked_BuildRequest(buildOptions: self.buildOptions), callOptions: callOptions).response.wait().successfull().vms.message
	}
}
