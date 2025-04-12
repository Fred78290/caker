import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC
import Logging
import TextTable
import Virtualization

struct Networks: ParsableCommand {
	static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Manage host network devices",
	                                                                      subcommands: [
	                                                                      	Networks.List.self,
	                                                                      	Networks.Create.self,
	                                                                      	Networks.Configure.self,
	                                                                      	Networks.DHCPLease.self,
	                                                                      	Networks.Delete.self,
	                                                                      	Networks.Run.self,
	                                                                      	Networks.Start.self,
	                                                                      	Networks.Stop.self])
	struct DHCPLease: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Start named network device.", discussion: "This command is used to set the dhcp lease")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(help: "DHCP lease time in seconds")
		var dhcpLease: Int32 = 300

		func validate() throws {
			if geteuid() != 0 {
				throw ValidationError("This command must be run as root not as user \(geteuid())")
			}

			if ProcessInfo.processInfo.environment["CAKE_HOME"] == nil {
				throw ValidationError("CAKE_HOME must be set to the correct location")
			}

			Logger.setLevel(self.logLevel)
		}
		
		func run() throws {
			try NetworksHandler.self.setDHCPLease(leaseTime: self.dhcpLease)
		}
	}

	struct Start: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Start named network device.", discussion: "This command is used to start the VMNet network device. CAKE_HOME must be set to the correct location.")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String

		mutating func validate() throws {
			if geteuid() != 0 {
				throw ValidationError("This command must be run as root not as user \(geteuid())")
			}


			if ProcessInfo.processInfo.environment["CAKE_HOME"] == nil {
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

		@OptionGroup var options: GRPCLib.NetworkCreateOptions

		var createdNetwork: VZSharedNetwork? = nil

		mutating func validate() throws {
			let home: Home = try Home(asSystem: runAsSystem)
			let networkConfig = try home.sharedNetworks()

			if networkConfig.sharedNetworks[self.options.name] != nil {
				throw ValidationError("Network \(self.options.name) already exist")
			}

			if NetworksHandler.isPhysicalInterface(name: self.options.name) {
				throw ValidationError("Network \(self.options.name) is a physical interface")
			}

			let network = VZSharedNetwork(
				mode: self.options.mode == .shared ? .shared : .host,
				netmask: self.options.subnetMask,
				dhcpStart: self.options.gateway,
				dhcpEnd: self.options.dhcpEnd,
				dhcpLease: self.options.dhcpLease,
				interfaceID: self.options.interfaceID,
				nat66Prefix: self.options.nat66Prefix
			)

			try network.validate()
			self.createdNetwork = network
			Logger.setLevel(self.logLevel)
		}

		func run() async throws {
			Logger.appendNewLine(try NetworksHandler.create(networkName: self.options.name, network: self.createdNetwork!, asSystem: self.asSystem))
		}
	}

	struct Configure: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Reconfigure named shared network")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Run caked as system agent, need sudo")
		var asSystem: Bool = false

		@OptionGroup var options: GRPCLib.NetworkConfigureOptions

		var changedNetwork: VZSharedNetwork? = nil

		mutating func validate() throws {
			let home: Home = try Home(asSystem: runAsSystem)
			let networkConfig = try home.sharedNetworks()

			if NetworksHandler.isPhysicalInterface(name: self.options.name) {
				throw ValidationError("Unable to configure physical network \(self.options.name)")
			}

			guard let existing = networkConfig.sharedNetworks[self.options.name] else {
				throw ValidationError("Network \(self.options.name) does not exist")
			}

			let changed = VZSharedNetwork(
				mode: existing.mode,
				netmask: self.options.subnetMask ?? existing.netmask,
				dhcpStart: self.options.gateway ?? existing.dhcpStart,
				dhcpEnd: self.options.dhcpEnd ?? existing.dhcpEnd,
				dhcpLease: self.options.dhcpLease ?? existing.dhcpLease,
				interfaceID: self.options.interfaceID ?? existing.interfaceID,
				nat66Prefix: self.options.nat66Prefix ?? existing.nat66Prefix
			)

			if existing != changed {
				try changed.validate()
			}

			self.changedNetwork = changed
			Logger.setLevel(self.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(try NetworksHandler.configure(networkName: self.options.name, network: self.changedNetwork!, asSystem: self.asSystem))
		}
	}

	struct Delete: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Delete existing shared network")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Run caked as system agent, need sudo")
		var asSystem: Bool = false

		@Argument(help: ArgumentHelp("network name", discussion: "network to delete, e.g. \"shared\""))
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
			Logger.appendNewLine(try NetworksHandler.delete(networkName: self.name, asSystem: self.asSystem))
		}
	}

	struct Run: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Start VMNet network device", shouldDisplay: false)

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@OptionGroup var options: NetworksHandler.VMNetOptions

		mutating func validate() throws {
			if geteuid() != 0 {
				throw ValidationError("This command must be run as root not as user \(geteuid())")
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

		@Argument(help: ArgumentHelp("network name", discussion: "network to stop, e.g., \"en0\" or \"shared\""))
		var networkName: String? = nil

		@Option(name: [.customLong("pidfile")], help: .hidden)
		var pidFile: String? = nil

		@Option(name: [.customLong("signal")], help: .hidden)
		var sig: Int32 = SIGTERM

		func validate() throws {
			Logger.setLevel(self.logLevel)

			if networkName != nil && pidFile != nil {
				throw ValidationError("You can only specify one of --network or --pidfile")
			}

			if networkName == nil && pidFile == nil {
				throw ValidationError("You must specify one of --network or --pidfile")
			}

			runAsSystem = self.asSystem
		}

		func run() throws {
			if let pidFile {
				Logger.appendNewLine(try NetworksHandler.stop(pidURL: URL(fileURLWithPath: pidFile), asSystem: self.asSystem))
			} else if let networkName {
				Logger.appendNewLine(try NetworksHandler.stop(networkName: networkName, asSystem: self.asSystem))
			} else {
				throw ValidationError("No network name provided")
			}
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
			Logger.appendNewLine(self.format.render(try NetworksHandler.networks(asSystem: asSystem)))
		}
	}
}
