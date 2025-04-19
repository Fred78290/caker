import Foundation
import ArgumentParser
import GRPCLib
import GRPC

struct ImagesManagement: ParsableCommand {
	static let configuration = CommandConfiguration(commandName: "image", abstract: "Manage simplestream images",
	                                                subcommands: [ListImage.self, InfoImage.self, PullImage.self])

	struct ListImage : GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "list", abstract: "List images")

		@OptionGroup var options: Client.Options

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Remote name")
		var name: String

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.image(Caked_ImageRequest(command: self), callOptions: callOptions).response.wait().successfull().images.list.infos)
		}
	}

	struct InfoImage : GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "info", abstract: "Show useful information about images")

		@OptionGroup var options: Client.Options

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Image name")
		var name: String

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.image(Caked_ImageRequest(command: self), callOptions: callOptions).response.wait().successfull().images.infos)
		}
	}

	struct PullImage : GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "info", abstract: "Show useful information about images")

		@OptionGroup var options: Client.Options

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Image name")
		var name: String

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.image(Caked_ImageRequest(command: self), callOptions: callOptions).response.wait().successfull().images.pull)
		}
	}
}
