import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Build: GrpcParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Create a linux VM and initialize it with cloud-init")

	@OptionGroup var options: Client.Options
	@OptionGroup var buildOptions: GRPCLib.BuildOptions

	func validate() throws {
		if buildOptions.name.contains("/") {
			throw ValidationError("\(buildOptions.name) should be a local name")
		}
	}

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.build(Caked_BuildRequest(buildOptions: self.buildOptions), callOptions: callOptions).response.wait()
	}
}
