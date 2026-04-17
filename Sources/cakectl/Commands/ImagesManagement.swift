import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct ImagesManagement: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "image", abstract: String(localized: "Manage simplestream images"),
		subcommands: [ListImage.self, InfoImage.self, PullImage.self])

	struct ListImage: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "list", abstract: String(localized: "List images"), aliases: ["ls"])

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "Remote name")))
		var name: String

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let result = try client.image(Caked_ImageRequest(command: self), callOptions: callOptions).response.wait().images.list

			if result.success {
				return self.options.format.render(result.infos)
			} else {
				return self.options.format.render(result.reason)
			}
		}
	}

	struct InfoImage: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "info", abstract: String(localized: "Show useful information about images"))

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "Image name")))
		var name: String

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let result = try client.image(Caked_ImageRequest(command: self), callOptions: callOptions).response.wait().images.infos

			if result.success {
				return self.options.format.render(result.info)
			} else {
				return self.options.format.render(result.reason)
			}
		}
	}

	struct PullImage: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(commandName: "info", abstract: String(localized: "Show useful information about images"))

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "Image name")))
		var name: String

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let result = try client.image(Caked_ImageRequest(command: self), callOptions: callOptions).response.wait().images.pull

			if result.success {
				return self.options.format.render(result.info)
			} else {
				return self.options.format.render(result.reason)
			}
		}
	}
}
