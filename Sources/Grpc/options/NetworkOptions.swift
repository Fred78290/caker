import ArgumentParser
import Foundation

public struct NetworkInfoOptions {
	public static let configuration = CommandConfiguration(abstract: "Network infos", discussion: "This command is used retrieve the network device information")
}

public struct NetworkDeleteOptions {
	public static let configuration = CommandConfiguration(abstract: "Delete named shared network")
}

public struct NetworkStartOptions {
	public static let configuration = CommandConfiguration(abstract: "Start named network")
}

public struct NetworkStopOptions {
	public static let configuration = CommandConfiguration(abstract: "Stop named network")
}

public struct NetworkListOptions {
	public static let configuration = CommandConfiguration(
		abstract:
			"""
			List host network devices (physical interfaces, virtual switches, bridges) available
			to integrate with using the `--bridged` switch to the `launch` command
			""")
}

public struct NetworkCreateOptions: ParsableArguments, Sendable {
	public static let configuration = CommandConfiguration(abstract: "Create named shared or host network")

	@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
	public var name: String

	@Option(name: [.customLong("mode")], help: "vmnet mode")
	public var mode = CreatedNetworkMode.shared

	@Option(name: [.customLong("gateway")], help: ArgumentHelp("IP gateway", discussion: "first ip used for the configured shared network, e.g., \"192.168.105.1\"", valueName: "ip"))
	public var gateway: String = "192.168.105.1"

	@Option(name: [.customLong("dhcp-end")], help: ArgumentHelp("Last ip of the DHCP range, e.g., \"192.168.105.254\"", discussion: "requires --gateway to be specified", valueName: "ip"))
	public var dhcpEnd: String = "192.168.105.254"

	@Option(help: ArgumentHelp("DHCP lease timeout", valueName: "seconds"))
	public var dhcpLease: Int32 = 300

	@Option(name: [.customLong("netmask")], help: ArgumentHelp("Subnet mask", discussion: "requires --gateway to be specified"))
	public var subnetMask = "255.255.255.0"

	@Option(name: [.customLong("interface-id")], help: ArgumentHelp("VMNET interface ID", discussion: "randomly generated if not specified", valueName: "uuid"))
	public var interfaceID = UUID().uuidString

	@Option(name: [.customLong("nat66-prefix")], help: ArgumentHelp("The IPv6 prefix to use with shared mode", valueName: "prefix"))
	public var nat66Prefix: String? = nil

	public init() {
	}

}

public struct NetworkConfigureOptions: ParsableArguments, Sendable {
	public static let configuration = CommandConfiguration(abstract: "Configure named shared network")

	@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
	public var name: String

	@Option(name: [.customLong("gateway")], help: ArgumentHelp("IP gateway", discussion: "First ip used for the configured shared network, e.g., \"192.168.105.1\"", valueName: "ip"))
	public var gateway: String? = nil

	@Option(name: [.customLong("dhcp-end")], help: ArgumentHelp("Last ip of the DHCP range, e.g., \"192.168.105.254\"", discussion: "requires --gateway to be specified", valueName: "ip"))
	public var dhcpEnd: String? = nil

	@Option(help: ArgumentHelp("DHCP lease timeout", valueName: "seconds"))
	public var dhcpLease: Int32? = nil

	@Option(name: [.customLong("netmask")], help: ArgumentHelp("Subnet mask", discussion: "requires --gateway to be specified"))
	public var subnetMask: String? = nil

	@Option(name: [.customLong("interface-id")], help: ArgumentHelp("VMNET interface ID", discussion: "randomly generated if not specified", valueName: "uuid"))
	public var interfaceID: String? = nil

	@Option(name: [.customLong("nat66-prefix")], help: ArgumentHelp("The IPv6 prefix to use with shared mode", valueName: "prefix"))
	public var nat66Prefix: String? = nil

	public init() {
	}

}
