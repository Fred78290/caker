import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC
import Logging
import TextTable

struct Networks: ParsableCommand {
	static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Manage host network devices",
	                                                                      subcommands: [
	                                                                      	Networks.List.self,
	                                                                      	Networks.Create.self,
	                                                                      	Networks.Configure.self,
	                                                                      	Networks.Delete.self,
	                                                                      	Networks.Run.self,
	                                                                      	Networks.Start.self,
	                                                                      	Networks.Stop.self])

	struct Start: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Start named network device.", discussion: "This command is used to start the VMNet network device. CAKE_HOME must be set to the correct location.")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String

		mutating func validate() throws {
			if geteuid() != 0 {
				throw ValidationError("This command must be run as root")
			}

			if ProcessInfo.processInfo.environment["CAKE_HOME"] == nil {
				print(ProcessInfo.processInfo.environment)
				throw ValidationError("CAKE_HOME must be set to the correct location")
			}

			if NetworksHandler.isPhysicalInterface(name: name) == false {
				let home: Home = try Home(asSystem: runAsSystem)
				let networkConfig = try home.sharedNetworks()

				if networkConfig.sharedNetworks[self.name] == nil {
					throw ValidationError("Network \(self.name) does not exist")
				}
			}

			Logger.setLevel(self.logLevel)
		}

		func run() throws {
			let options: NetworksHandler.VMNetOptions = try NetworksHandler.VMNetOptions(networkName: self.name, asSystem: false)

			try NetworksHandler.self.start(options: options)
		}
	}

	struct Create: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Create named shared network")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Run caked as system agent, need sudo")
		var asSystem: Bool = false

		@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String

		@Option(name: [.customLong("dhcp-start")], help: ArgumentHelp("IP gateway", discussion: "firt ip used for the configured shared network, e.g., \"192.168.105.1\""))
		var gateway: String = "192.168.105.1"

		@Option(name: [.customLong("dhcp-end")], help: "end of the DHCP range")
		var dhcpEnd: String = "192.168.105.254"

		@Option(name: [.customLong("netmask")], help: ArgumentHelp("subnet mask", discussion: "requires --gateway to be specified"))
		var subnetMask = "255.255.255.0"

		@Option(name: [.customLong("interface-id")], help: ArgumentHelp("vmnet interface ID", discussion: "randomly generated if not specified"))
		var interfaceID = UUID().uuidString

		@Option(name: [.customLong("nat66-prefix")], help: "The IPv6 prefix to use with shared mode")
		var nat66Prefix: String? = nil

		var createdNetwork: VZSharedNetwork? = nil

		mutating func validate() throws {
			let home: Home = try Home(asSystem: runAsSystem)
			let networkConfig = try home.sharedNetworks()

			if networkConfig.sharedNetworks[self.name] != nil {
				throw ValidationError("Network \(self.name) already exist")
			}

			if NetworksHandler.isPhysicalInterface(name: self.name) {
				throw ValidationError("Network \(self.name) is a physical interface")
			}

			let network = VZSharedNetwork(
				netmask: self.subnetMask,
				dhcpStart: self.gateway,
				dhcpEnd: self.dhcpEnd,
				uuid: self.interfaceID,
				nat66Prefix: self.nat66Prefix
			)

			try network.validate()
			self.createdNetwork = network
			Logger.setLevel(self.logLevel)
		}

		func run() async throws {
			try NetworksHandler.create(networkName: self.name, network: self.createdNetwork!, asSystem: self.asSystem)
			print("Network \(self.name) created")
		}
	}

	struct Configure: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Reconfigure named shared network")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Run caked as system agent, need sudo")
		var asSystem: Bool = false

		@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String

		@Option(name: [.customLong("dhcp-start")], help: ArgumentHelp("IP gateway", discussion: "first ip used for the configured shared network, e.g., \"192.168.105.1\""))
		var gateway: String? = nil

		@Option(name: [.customLong("dhcp-end")], help: "end of the DHCP range")
		var dhcpEnd: String? = nil

		@Option(name: [.customLong("netmask")], help: ArgumentHelp("subnet mask", discussion: "requires --gateway to be specified"))
		var subnetMask: String? = nil

		@Option(name: [.customLong("interface-id")], help: ArgumentHelp("vmnet interface ID", discussion: "randomly generated if not specified"))
		var interfaceID: String? = nil

		@Option(name: [.customLong("nat66-prefix")], help: "The IPv6 prefix to use with shared mode")
		var nat66Prefix: String? = nil

		var changedNetwork: VZSharedNetwork? = nil

		mutating func validate() throws {
			let home: Home = try Home(asSystem: runAsSystem)
			let networkConfig = try home.sharedNetworks()

			if NetworksHandler.isPhysicalInterface(name: self.name) {
				throw ValidationError("Unable to configure physical network \(self.name)")
			}

			guard let existing = networkConfig.sharedNetworks[self.name] else {
				throw ValidationError("Network \(self.name) does not exist")
			}

			let changed = VZSharedNetwork(
				netmask: self.subnetMask ?? existing.netmask,
				dhcpStart: self.gateway ?? existing.dhcpStart,
				dhcpEnd: self.dhcpEnd ?? existing.dhcpEnd,
				uuid: self.interfaceID ?? existing.uuid,
				nat66Prefix: self.nat66Prefix ?? existing.nat66Prefix
			)

			try changed.validate()

			self.changedNetwork = changed
			Logger.setLevel(self.logLevel)
		}

		func run() throws {
			try NetworksHandler.configure(networkName: self.name, network: self.changedNetwork!, asSystem: self.asSystem)
			print("Network \(self.name) reconfigured")
		}
	}

	struct Delete: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Delete existing shared network")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Run caked as system agent, need sudo")
		var asSystem: Bool = false

		@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String

		mutating func validate() throws {
			let home: Home = try Home(asSystem: runAsSystem)
			let networkConfig = try home.sharedNetworks()

			if NetworksHandler.isPhysicalInterface(name: self.name) {
				throw ValidationError("Unable to delete physical network \(self.name)")
			}

			if networkConfig.sharedNetworks[self.name] == nil {
				throw ValidationError("Network \(self.name) does not exist")
			}

			Logger.setLevel(self.logLevel)
		}

		func run() throws {
			try NetworksHandler.delete(networkName: self.name, asSystem: self.asSystem)
			print("Network \(self.name) deleted")
		}
	}

	struct Run: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Start VMNet network device", shouldDisplay: false)

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@OptionGroup var options: NetworksHandler.VMNetOptions

		mutating func validate() throws {
			if geteuid() != 0 {
				throw ValidationError("This command must be run as root")
			}

			Logger.setLevel(self.logLevel)
			try self.options.validate()
		}

		func run() async throws {
			try NetworksHandler.start(options: self.options)
		}
	}

	struct Stop: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Stop VMNet network device")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Run caked as system agent, need sudo")
		var asSystem: Bool = false

		@Option(name: [.customLong("name")], help: ArgumentHelp("network name", discussion: "network to stop, e.g., \"en0\" or \"shared\""))
		var networkName: String

		func validate() throws {
			Logger.setLevel(self.logLevel)

			runAsSystem = self.asSystem
		}

		func run() throws {
			Logger.appendNewLine(try NetworksHandler.stop(networkName: self.networkName, asSystem: self.asSystem))
		}
	}

	struct List: ParsableCommand {
		static let configuration = CommandConfiguration(abstract:
			"""
			List host network devices (physical interfaces, virtual switches, bridges) available
			to integrate with using the `--network` switch to the `launch` command
			""")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Run caked as system agent, need sudo")
		var asSystem: Bool = false

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.format.renderList(style: Style.grid, uppercased: true, try NetworksHandler.networks(asSystem: asSystem)))
		}
	}
}
