import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Networks: ParsableCommand {
	static let configuration: CommandConfiguration = CommandConfiguration(
		abstract: String(localized: "Manage host network devices"),
		subcommands: [
			Networks.Infos.self,
			Networks.List.self,
			Networks.Create.self,
			Networks.Configure.self,
			Networks.Delete.self,
			Networks.Start.self,
			Networks.Stop.self,
		], aliases: ["net"])

	struct Infos: GrpcParsableCommand {
		static let configuration = NetworkInfoOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "Network name"), discussion: String(localized: "network to retrieve, e.g. \"shared\"")))
		var name: String = "shared"

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let status = try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().networks.status

			if status.success {
				return self.options.format.render(status.info)
			} else {
				throw GrpcError(code: 1, reason: status.reason)
			}
		}
	}

	struct Create: GrpcParsableCommand {
		static let configuration = NetworkCreateOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@OptionGroup(title: String(localized: "Create network options"))
		var networkOptions: NetworkCreateOptions

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.options.format.render(try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().networks.created)
		}
	}

	struct Configure: GrpcParsableCommand {
		static let configuration = NetworkConfigureOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@OptionGroup(title: String(localized: "Configure network options"))
		var networkOptions: NetworkConfigureOptions

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.options.format.render(try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().networks.configured)
		}
	}

	struct Delete: GrpcParsableCommand {
		static let configuration = NetworkDeleteOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "Network name"), discussion: String(localized: "network to delete, e.g. \"shared\"")))
		var name: String = "shared"

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.options.format.render(try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().networks.delete)
		}
	}

	struct Start: GrpcParsableCommand {
		static let configuration = NetworkStartOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "network name"), discussion: String(localized: "network to start, e.g., \"en0\" or \"shared\"")))
		var name: String = "shared"

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.options.format.render(try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().networks.started)
		}
	}

	struct Stop: GrpcParsableCommand {
		static let configuration = NetworkStopOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "network name"), discussion: String(localized: "network to stop, e.g., \"en0\" or \"shared\"")))
		var name: String = "shared"

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.options.format.render(try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().networks.stopped)
		}
	}

	struct List: GrpcParsableCommand {
		static let configuration = NetworkListOptions.configuration

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let result = try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().networks.list

			if result.success {
				return self.options.format.render(result.networks)
			} else {
				return self.options.format.render(result.reason)
			}
		}
	}
}
