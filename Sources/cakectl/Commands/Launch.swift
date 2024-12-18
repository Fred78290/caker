import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Launch : GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Create a linux VM, initialize it with cloud-init and launch in background")

	@OptionGroup var options: Client.Options
	@OptionGroup var buildOptions: GRPCLib.BuildOptions

	@Option(help:"Maximum of seconds to getting IP")
	var waitIPTimeout = 180

	func validate() throws {
		try self.buildOptions.validate()
	}

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.launch(Caked_LaunchRequest(command: self), callOptions: callOptions).response.wait()
	}
}
