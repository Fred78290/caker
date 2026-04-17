import ArgumentParser
import Foundation

public struct NetworkInfoOptions {
	public static let configuration = CommandConfiguration(abstract: String(localized: "Network infos"), discussion: String(localized: "This command is used retrieve the network device information"))
}

public struct NetworkDeleteOptions {
	public static let configuration = CommandConfiguration(abstract: String(localized: "Delete named shared network"))
}

public struct NetworkStartOptions {
	public static let configuration = CommandConfiguration(abstract: String(localized: "Start named network"))
}

public struct NetworkStopOptions {
	public static let configuration = CommandConfiguration(abstract: String(localized: "Stop named network"))
}

public struct NetworkListOptions {
	public static let configuration = CommandConfiguration(abstract: String(localized: "network_list_abstract"), aliases: ["ls"])
}


public struct NetworkCreateOptions: ParsableArguments, Sendable {
	public static let configuration = CommandConfiguration(abstract: String(localized: "Create named shared or host network"))

	@Option(name: [.customLong("mode")], help: ArgumentHelp(String(localized: "vmnet mode")))
	public var mode = CreatedNetworkMode.shared

	@Option(name: [.customLong("gateway")], help: ArgumentHelp(String(localized: "IP gateway"), discussion: String(localized: "first ip used for the configured shared network, e.g., \"192.168.105.1\""), valueName: "ip"))
	public var gateway: String = "192.168.105.1"

	@Option(name: [.customLong("dhcp-end")], help: ArgumentHelp(String(localized: "Last ip of the DHCP range, e.g., \"192.168.105.254\""), discussion: String(localized: "requires --gateway to be specified"), valueName: "ip"))
	public var dhcpEnd: String = "192.168.105.254"

	@Option(help: ArgumentHelp(String(localized: "DHCP lease timeout"), valueName: "seconds"))
	public var dhcpLease: Int32 = 300

	@Option(name: [.customLong("netmask")], help: ArgumentHelp(String(localized: "Subnet mask"), discussion: String(localized: "requires --gateway to be specified")))
	public var subnetMask = "255.255.255.0"

	@Option(name: [.customLong("interface-id")], help: ArgumentHelp(String(localized: "VMNET interface ID"), discussion: String(localized: "randomly generated if not specified"), valueName: "uuid"))
	public var interfaceID = UUID().uuidString

	@Option(name: [.customLong("nat66-prefix")], help: ArgumentHelp(String(localized: "The IPv6 prefix to use with shared mode"), valueName: "prefix"))
	public var nat66Prefix: String? = nil

	@Argument(help: ArgumentHelp(String(localized: "Network name"), discussion: String(localized: "The name for network")))
	public var name: String

	public init() {
	}

}

public struct NetworkConfigureOptions: ParsableArguments, Sendable {
	public static let configuration = CommandConfiguration(abstract: String(localized: "Configure named shared network"))

	@Option(name: [.customLong("gateway")], help: ArgumentHelp(String(localized: "IP gateway"), discussion: String(localized: "first ip used for the configured shared network, e.g., \"192.168.105.1\""), valueName: "ip"))
	public var gateway: String? = nil

	@Option(name: [.customLong("dhcp-end")], help: ArgumentHelp(String(localized: "Last ip of the DHCP range, e.g., \"192.168.105.254\""), discussion: String(localized: "requires --gateway to be specified"), valueName: "ip"))
	public var dhcpEnd: String? = nil

	@Option(help: ArgumentHelp(String(localized: "DHCP lease timeout"), valueName: "seconds"))
	public var dhcpLease: Int32? = nil

	@Option(name: [.customLong("netmask")], help: ArgumentHelp(String(localized: "Subnet mask"), discussion: String(localized: "requires --gateway to be specified")))
	public var subnetMask: String? = nil

	@Option(name: [.customLong("interface-id")], help: ArgumentHelp(String(localized: "VMNET interface ID"), discussion: String(localized: "randomly generated if not specified"), valueName: "uuid"))
	public var interfaceID: String? = nil

	@Option(name: [.customLong("nat66-prefix")], help: ArgumentHelp(String(localized: "The IPv6 prefix to use with shared mode"), valueName: "prefix"))
	public var nat66Prefix: String? = nil

	@Argument(help: ArgumentHelp(String(localized: "Network name"), discussion: String(localized: "The name for network")))
	public var name: String

	public init() {
	}

}
