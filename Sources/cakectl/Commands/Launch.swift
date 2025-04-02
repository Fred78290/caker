import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Launch : GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Create a linux VM, initialize it with cloud-init and launch in background")

	@OptionGroup var options: Client.Options
	@OptionGroup var buildOptions: GRPCLib.BuildOptions

	@Option(help:"Maximum of seconds to getting IP")
	var waitIPTimeout = 180

	mutating func validate() throws {
		try self.buildOptions.validate()

		if buildOptions.sockets.first(where: { $0.sharedFileDescriptors != nil }) != nil {
			throw ValidationError("Shared file descriptors are not supported, use caked launch instead")
		}
	}

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.launch(Caked_LaunchRequest(command: self), callOptions: callOptions).response.wait()
	}
}
