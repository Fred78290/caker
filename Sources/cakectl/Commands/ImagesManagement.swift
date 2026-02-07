import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct ImagesManagement: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "image", abstract: "Manage simplestream images",
		subcommands: [ListImage.self, InfoImage.self, PullImage.self])

	struct ListImage: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "list", abstract: "List images")

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Remote name")
		var name: String

		func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let result = try client.image(Caked_ImageRequest(command: self), callOptions: callOptions).response.wait().images.list

			if result.success {
				return self.format.render(result.infos)
			} else {
				return self.format.render(result.reason)
			}
		}
	}

	struct InfoImage: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "info", abstract: "Show useful information about images")

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Image name")
		var name: String

		func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let result = try client.image(Caked_ImageRequest(command: self), callOptions: callOptions).response.wait().images.infos

			if result.success {
				return self.format.render(result.info)
			} else {
				return self.format.render(result.reason)
			}
		}
	}

	struct PullImage: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "info", abstract: "Show useful information about images")

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Image name")
		var name: String

		func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let result = try client.image(Caked_ImageRequest(command: self), callOptions: callOptions).response.wait().images.pull

			if result.success {
				return self.format.render(result.info)
			} else {
				return self.format.render(result.reason)
			}
		}
	}
}
