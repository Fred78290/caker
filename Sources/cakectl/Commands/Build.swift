import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Build: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Create a linux VM and initialize it with cloud-init")

	@OptionGroup var options: Client.Options
	@OptionGroup var buildOptions: GRPCLib.BuildOptions

	mutating func validate() throws {
		try buildOptions.validate()

		if buildOptions.sockets.first(where: { $0.sharedFileDescriptors != nil }) != nil {
			throw ValidationError("Shared file descriptors are not supported, use launch instead")
		}
	}

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.build(Caked_BuildRequest(buildOptions: self.buildOptions), callOptions: callOptions).response.wait()
	}
}
