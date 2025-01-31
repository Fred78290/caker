import Foundation
import ArgumentParser
import GRPCLib
import GRPC

struct ImagesManagement: ParsableCommand {
	static var configuration = CommandConfiguration(commandName: "image", abstract: "Manage simplestream images",
	                                                subcommands: [ListImage.self, InfoImage.self])

	struct ListImage : GrpcParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(commandName: "list", abstract: "List images")

		@OptionGroup var options: Client.Options

		@Option(help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Remote name")
		var name: String

		func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.image(Caked_ImageRequest(command: self), callOptions: callOptions).response.wait()
		}
	}

	struct InfoImage : GrpcParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(commandName: "info", abstract: "Show useful information about images")

		@OptionGroup var options: Client.Options

		@Option(help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Image name")
		var name: String

		func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.image(Caked_ImageRequest(command: self), callOptions: callOptions).response.wait()
		}
	}
}