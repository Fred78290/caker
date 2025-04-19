import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Launch : GrpcParsableCommand {
	static let configuration = BuildOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Launch VM options")
	var buildOptions: BuildOptions

	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
	var waitIPTimeout = 180

	func validate() throws {
		if buildOptions.sockets.first(where: { $0.sharedFileDescriptors != nil }) != nil {
			throw ValidationError("Shared file descriptors are not supported, use caked launch instead")
		}
	}

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.launch(Caked_LaunchRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.message
	}
}
