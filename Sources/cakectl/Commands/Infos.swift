import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Infos: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "infos", abstract: "Get info for VM")

	@OptionGroup var options: Client.Options

	@Option(help: "Output format: text or json")
	var format: Format = .text

	@Argument(help: "VM name")
	var name: String

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.info(Caked_InfoRequest(command: self), callOptions: callOptions).response.wait()
	}
}
