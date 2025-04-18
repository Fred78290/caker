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
	                                                                      	Networks.Infos.self,
	                                                                      	Networks.List.self,
	                                                                      	Networks.Create.self,
	                                                                      	Networks.Configure.self,
	                                                                      	Networks.DHCPLease.self,
	                                                                      	Networks.Delete.self,
	                                                                      	Networks.Run.self,
	                                                                      	Networks.Start.self,
	                                                                      	Networks.Restart.self,
	                                                                      	Networks.Stop.self])

	static func validateNetwork(networkName: String, asSystem: Bool) throws {
		// Validate the network name
		if NetworksHandler.isPhysicalInterface(name: networkName) == false {
			let home: Home = try Home(asSystem: asSystem)
			let networkConfig = try home.sharedNetworks()

			if networkConfig.sharedNetworks[networkName] == nil {
				throw ValidationError("Network \(networkName) does not exist")
			}
		}
	}

	struct Infos: ParsableCommand {
		static let configuration = CommandConfiguration(commandName: "infos", abstract: "Network infos", discussion: "This command is used retrieve the network device information")

		@OptionGroup var common: CommonOptions

		@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String

		func validate() throws {
			Logger.setLevel(self.common.logLevel)

			try validateNetwork(networkName: self.name, asSystem: self.common.asSystem)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.status(networkName: self.name, asSystem: self.common.asSystem)))
		}
	}

	struct DHCPLease: ParsableCommand {
		static let configuration = CommandConfiguration(commandName: "set-dhcp-lease", abstract: "Set DHCP lease duration.", discussion: "This command is used to set the dhcp lease")

		@OptionGroup var common: CommonOptions

		@Argument(help: "DHCP lease time in seconds")
		var dhcpLease: Int32 = 300

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.setDHCPLease(leaseTime: self.dhcpLease, asSystem: self.common.asSystem)))
		}
	}

	struct Start: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Start named network device.", discussion: "This command is used to start the VMNet network device location.")

		@OptionGroup var common: CommonOptions

		@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)

			try validateNetwork(networkName: self.name, asSystem: self.common.asSystem)

			let socketURL = try NetworksHandler.vmnetEndpoint(networkName: name, asSystem: self.common.asSystem)

			if FileManager.default.fileExists(atPath: socketURL.0.path) {
				throw ValidationError("Network \(self.name) already running")
			}
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.start(options: try NetworksHandler.VMNetOptions(networkName: self.name, asSystem: self.common.asSystem), asSystem: self.common.asSystem)))
		}
	}

	struct Restart: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Restart named network device.", discussion: "This command is used to restart the VMNet network device.")

		@OptionGroup var common: CommonOptions

		@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)

			try validateNetwork(networkName: self.name, asSystem: self.common.asSystem)

			let socketURL = try NetworksHandler.vmnetEndpoint(networkName: name, asSystem: self.common.asSystem)

			if FileManager.default.fileExists(atPath: socketURL.0.path) == false {
				throw ValidationError("Network \(self.name) is not running")
			}
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.restartNetworkService(networkName: self.name, asSystem: self.common.asSystem)))
		}
	}

	struct Create: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Create named shared network")

		@OptionGroup var common: CommonOptions

		@OptionGroup var options: GRPCLib.NetworkCreateOptions

		var createdNetwork: VZSharedNetwork? = nil

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)

			let home: Home = try Home(asSystem: self.common.asSystem)
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
		}

		func run() async throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.create(networkName: self.options.name, network: self.createdNetwork!, asSystem: self.common.asSystem)))
		}
	}

	struct Configure: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Reconfigure named shared network")

		@OptionGroup var common: CommonOptions

		@OptionGroup var options: GRPCLib.NetworkConfigureOptions

		var changedNetwork: VZSharedNetwork? = nil

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)

			let home: Home = try Home(asSystem: self.common.asSystem)
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
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.configure(networkName: self.options.name, network: self.changedNetwork!, asSystem: self.common.asSystem)))
		}
	}

	struct Delete: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Delete existing shared network")

		@OptionGroup var common: CommonOptions

		@Argument(help: ArgumentHelp("network name", discussion: "network to delete, e.g. \"shared\""))
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)

			let home: Home = try Home(asSystem: self.common.asSystem)
			let networkConfig = try home.sharedNetworks()
			let socketURL = try NetworksHandler.vmnetEndpoint(networkName: self.name, asSystem: self.common.asSystem)

			if FileManager.default.fileExists(atPath: socketURL.0.path) {
				throw ValidationError("Unable to delete running network \(self.name)")
			}

			if NetworksHandler.isPhysicalInterface(name: self.name) {
				throw ValidationError("Unable to delete physical network \(self.name)")
			}

			if networkConfig.sharedNetworks[self.name] == nil {
				throw ValidationError("Network \(self.name) does not exist")
			}
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.delete(networkName: self.name, asSystem: self.common.asSystem)))
		}
	}

	struct Run: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Run internal VMNet network device", shouldDisplay: false)

		@OptionGroup var common: CommonOptions

		@OptionGroup var options: NetworksHandler.VMNetOptions

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)

			let socketURL = try self.options.vmnetEndpoint(asSystem: self.common.asSystem)

			if FileManager.default.fileExists(atPath: socketURL.0.path) {
				throw ValidationError("Network already running")
			}

			if geteuid() != 0 {
				throw ValidationError("This command must be run as root not as user \(geteuid())")
			}

			if FileManager.default.fileExists(atPath: socketURL.0.path) {
				throw ValidationError("Network already running")
			}

			try self.options.validate()
		}

		func run() async throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.start(options: self.options, asSystem: self.common.asSystem)))
		}
	}

	struct Stop: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Stop VMNet network device")

		@OptionGroup var common: CommonOptions

		@Argument(help: ArgumentHelp("network name", discussion: "network to stop, e.g., \"en0\" or \"shared\""))
		var networkName: String? = nil

		@Option(name: [.customLong("pidfile")], help: .hidden)
		var pidFile: String? = nil

		func validate() throws {
			Logger.setLevel(self.common.logLevel)

			if networkName != nil && pidFile != nil {
				throw ValidationError("You can only specify one of --network or --pidfile")
			}

			if networkName == nil && pidFile == nil {
				throw ValidationError("You must specify one of --network or --pidfile")
			}

			if let networkName {
				try Networks.validateNetwork(networkName: networkName, asSystem: self.common.asSystem)
			} else if let pidFile {
				if !FileManager.default.fileExists(atPath: pidFile) {
					throw ValidationError("PID file \(pidFile) does not exist")
				}
			}
		}

		func run() throws {
			if let pidFile {
				Logger.appendNewLine(self.common.format.render(try NetworksHandler.stop(pidURL: URL(fileURLWithPath: pidFile), asSystem: self.common.asSystem)))
			} else if let networkName {
				Logger.appendNewLine(self.common.format.render(try NetworksHandler.stop(networkName: networkName, asSystem: self.common.asSystem)))
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

		@OptionGroup var common: CommonOptions

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.networks(asSystem: self.common.asSystem)))
		}
	}
}
