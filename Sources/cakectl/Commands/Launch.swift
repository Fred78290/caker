import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Launch: GrpcParsableCommand {
	static let configuration = BuildOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Launch VM options")
	var buildOptions: BuildOptions

	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
	var waitIPTimeout = 180

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func validate() throws {
		if buildOptions.sockets.first(where: { $0.sharedFileDescriptors != nil }) != nil {
			throw ValidationError("Shared file descriptors are not supported, use caked launch instead")
		}
	}

	func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.launch(Caked_LaunchRequest(command: self), callOptions: callOptions).response.wait().vms.launched)
	}
}
