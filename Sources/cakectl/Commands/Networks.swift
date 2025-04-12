import Foundation
import ArgumentParser
import GRPC
import GRPCLib

struct Networks: ParsableCommand {
	static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Manage host network devices",
	                                                                      subcommands: [Networks.List.self,
	                                                                                    Networks.Create.self,
	                                                                                    Networks.Configure.self,
	                                                                                    Networks.Delete.self,
	                                                                                    Networks.Start.self,
	                                                                                    Networks.Stop.self])

	struct Create: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Create named shared network")

		@OptionGroup var options: Client.Options
		@OptionGroup var networkOptions: GRPCLib.NetworkCreateOptions

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().successfull().networks.message
		}
	}

	struct Configure: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Configure named shared network")

		@OptionGroup var options: Client.Options
		@OptionGroup var networkOptions: GRPCLib.NetworkConfigureOptions

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().successfull().networks.message
		}
	}

	struct Delete: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Delete named shared network")

		@OptionGroup var options: Client.Options

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: ArgumentHelp("Network name", discussion: "network to delete, e.g. \"shared\""))
		var name: String = "shared"

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().successfull().networks.message
		}
	}

	struct Start: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Start named shared network")

		@OptionGroup var options: Client.Options

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: ArgumentHelp("network name", discussion: "network to start, e.g., \"en0\" or \"shared\""))
		var name: String = "shared"

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().successfull().networks.message
		}
	}

	struct Stop: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Start named shared network")

		@OptionGroup var options: Client.Options

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: ArgumentHelp("network name", discussion: "network to stop, e.g., \"en0\" or \"shared\""))
		var name: String = "shared"

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().successfull().networks.message
		}
	}

	struct List: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: """
		List host network devices (physical interfaces, virtual switches, bridges) available
		to integrate with using the `--bridged` switch to the `launch` command
		""")

		@OptionGroup var options: Client.Options

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			return self.format.render(try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait().successfull().networks.list)
		}
	}
}
