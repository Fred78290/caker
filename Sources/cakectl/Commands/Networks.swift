import Foundation
import ArgumentParser
import GRPC
import GRPCLib

struct Networks: ParsableCommand {
	static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Manage host network devices",
	                                                                      subcommands: [Networks.List.self, Networks.Create.self, Networks.Configure.self, Networks.Delete.self, Networks.Start.self, Networks.Stop.self])

	struct Create: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Create named shared network")

		@OptionGroup var options: Client.Options

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Option(name: [.customLong("name")], help: ArgumentHelp("Network name", discussion: "The name for network."))
		var name: String = "shared"

		@Option(name: [.customLong("dhcp-start")], help: ArgumentHelp("IP gateway", discussion: "first ip used for the configured shared network, e.g., \"192.168.105.1\""))
		var gateway: String = "192.168.105.1"

		@Option(name: [.customLong("dhcp-end")], help: "end of the DHCP range")
		var dhcpEnd: String = "192.168.105.254"

		@Option(name: [.customLong("netmask")], help: ArgumentHelp("subnet mask", discussion: "requires --gateway to be specified"))
		var subnetMask = "255.255.255.0"

		@Option(name: [.customLong("interface-id")], help: ArgumentHelp("vmnet interface ID", discussion: "randomly generated if not specified"))
		var interfaceID = UUID().uuidString

		@Option(name: [.customLong("nat66-prefix")], help: "The IPv6 prefix to use with shared mode")
		var nat66Prefix: String? = nil

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait()
		}
	}

	struct Configure: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Configure named shared network")

		@OptionGroup var options: Client.Options

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Option(name: [.customLong("name")], help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String = "shared"

		@Option(name: [.customLong("dhcp-start")], help: ArgumentHelp("IP gateway", discussion: "firt ip used for the configured shared network, e.g., \"192.168.105.1\""))
		var gateway: String? = nil

		@Option(name: [.customLong("dhcp-end")], help: "end of the DHCP range")
		var dhcpEnd: String? = nil

		@Option(name: [.customLong("netmask")], help: ArgumentHelp("subnet mask", discussion: "requires --gateway to be specified"))
		var subnetMask: String? = nil

		@Option(name: [.customLong("interface-id")], help: ArgumentHelp("vmnet interface ID", discussion: "randomly generated if not specified"))
		var interfaceID: String? = nil

		@Option(name: [.customLong("nat66-prefix")], help: "The IPv6 prefix to use with shared mode")
		var nat66Prefix: String? = nil

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait()
		}
	}

	struct Delete: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Delete named shared network")

		@OptionGroup var options: Client.Options

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Option(name: [.customLong("name")], help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String = "shared"

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait()
		}
	}

	struct Start: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Start named shared network")

		@OptionGroup var options: Client.Options

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Option(name: [.customLong("name")], help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String = "shared"

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait()
		}
	}

	struct Stop: GrpcParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Start named shared network")

		@OptionGroup var options: Client.Options

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Option(name: [.customLong("name")], help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String = "shared"

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait()
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

		func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
			return try client.networks(Caked_NetworkRequest(command: self), callOptions: callOptions).response.wait()
		}
	}
}
