import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Networks: ParsableCommand {
	static let configuration: CommandConfiguration = CommandConfiguration(
		abstract: "Manage host network devices",
		subcommands: [
			Networks.Infos.self,
			Networks.List.self,
			Networks.Create.self,
			Networks.Configure.self,
			Networks.Delete.self,
			Networks.Start.self,
			Networks.Stop.self,
		])

	struct Infos: GrpcParsableCommand {
		static let configuration = NetworkInfoOptions.configuration

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: ArgumentHelp("Network name", discussion: "network to retrieve, e.g. \"shared\""))
		var name: String = "shared"

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().successfull().networks.status)
		}
	}

	struct Create: GrpcParsableCommand {
		static let configuration = NetworkCreateOptions.configuration

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@OptionGroup(title: "Create network options")
		var networkOptions: NetworkCreateOptions

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().successfull().networks.created)
		}
	}

	struct Configure: GrpcParsableCommand {
		static let configuration = NetworkConfigureOptions.configuration

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@OptionGroup(title: "Configure network options")
		var networkOptions: NetworkConfigureOptions

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().successfull().networks.configured)
		}
	}

	struct Delete: GrpcParsableCommand {
		static let configuration = NetworkDeleteOptions.configuration

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@Argument(help: ArgumentHelp("Network name", discussion: "network to delete, e.g. \"shared\""))
		var name: String = "shared"

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().successfull().networks.delete)
		}
	}

	struct Start: GrpcParsableCommand {
		static let configuration = NetworkStartOptions.configuration

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@Argument(help: ArgumentHelp("network name", discussion: "network to start, e.g., \"en0\" or \"shared\""))
		var name: String = "shared"

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().successfull().networks.started)
		}
	}

	struct Stop: GrpcParsableCommand {
		static let configuration = NetworkStopOptions.configuration

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: ArgumentHelp("network name", discussion: "network to stop, e.g., \"en0\" or \"shared\""))
		var name: String = "shared"

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().successfull().networks.stopped)
		}
	}

	struct List: GrpcParsableCommand {
		static let configuration = NetworkListOptions.configuration

		@OptionGroup(title: "Client options")
		var options: Client.Options

		@Flag(help: "Output format: text or json")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().successfull().networks.list)
		}
	}
}
