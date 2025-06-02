import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import Logging
import SwiftUI
import TextTable
import Virtualization

struct Networks: ParsableCommand {
	static let configuration: CommandConfiguration = CommandConfiguration(
		abstract: "Manage host network devices",
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
			Networks.Stop.self,
		])

	static func validateNetwork(networkName: String, runMode: Utils.RunMode) throws {
		// Validate the network name
		if NetworksHandler.isPhysicalInterface(name: networkName) == false {
			let home: Home = try Home(runMode: runMode)
			let networkConfig = try home.sharedNetworks()

			if networkConfig.sharedNetworks[networkName] == nil {
				throw ValidationError("Network \(networkName) does not exist")
			}
		}
	}

	struct Infos: ParsableCommand {
		static let configuration = NetworkInfoOptions.configuration

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String

		func validate() throws {
			Logger.setLevel(self.common.logLevel)

			try validateNetwork(networkName: self.name, runMode: self.common.runMode)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.status(networkName: self.name, runMode: self.common.runMode)))
		}
	}

	struct DHCPLease: ParsableCommand {
		static let configuration = CommandConfiguration(commandName: "set-dhcp-lease", abstract: "Set DHCP lease duration.", discussion: "This command is used to set the dhcp lease")

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@Argument(help: "DHCP lease time in seconds")
		var dhcpLease: Int32 = 300

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.setDHCPLease(leaseTime: self.dhcpLease, runMode: self.common.runMode)))
		}
	}

	struct Start: ParsableCommand {
		static let configuration = NetworkStartOptions.configuration

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)

			try validateNetwork(networkName: self.name, runMode: self.common.runMode)

			let socketURL = try NetworksHandler.vmnetEndpoint(networkName: name, runMode: self.common.runMode)

			if FileManager.default.fileExists(atPath: socketURL.0.path) {
				throw ValidationError("Network \(self.name) already running")
			}
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.start(options: try NetworksHandler.VMNetOptions(networkName: self.name, runMode: self.common.runMode), runMode: self.common.runMode)))
		}
	}

	struct Restart: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Restart named network.", discussion: "This command is used to restart the VMNet network device.")

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)

			try validateNetwork(networkName: self.name, runMode: self.common.runMode)

			let socketURL = try NetworksHandler.vmnetEndpoint(networkName: name, runMode: self.common.runMode)

			if FileManager.default.fileExists(atPath: socketURL.0.path) == false {
				throw ValidationError("Network \(self.name) is not running")
			}
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.restartNetworkService(networkName: self.name, runMode: self.common.runMode)))
		}
	}

	struct Create: AsyncParsableCommand {
		static let configuration = NetworkCreateOptions.configuration

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@OptionGroup(title: "Create networks options")
		var options: NetworkCreateOptions

		var createdNetwork: VZSharedNetwork? = nil

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)

			let home: Home = try Home(runMode: self.common.runMode)
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
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.create(networkName: self.options.name, network: self.createdNetwork!, runMode: self.common.runMode)))
		}
	}

	struct Configure: ParsableCommand {
		static let configuration = NetworkConfigureOptions.configuration

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@OptionGroup(title: "Configure networks options")
		var options: NetworkConfigureOptions

		var changedNetwork: VZSharedNetwork? = nil

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)

			let home: Home = try Home(runMode: self.common.runMode)
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
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.configure(networkName: self.options.name, network: self.changedNetwork!, runMode: self.common.runMode)))
		}
	}

	struct Delete: ParsableCommand {
		static let configuration = NetworkDeleteOptions.configuration

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@Argument(help: ArgumentHelp("network name", discussion: "network to delete, e.g. \"shared\""))
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)

			let home: Home = try Home(runMode: self.common.runMode)
			let networkConfig = try home.sharedNetworks()
			let socketURL = try NetworksHandler.vmnetEndpoint(networkName: self.name, runMode: self.common.runMode)

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
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.delete(networkName: self.name, runMode: self.common.runMode)))
		}
	}

	struct Run: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Run internal VMNet network device", shouldDisplay: false)

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@OptionGroup(title: "Configure VMNet options")
		var options: NetworksHandler.VMNetOptions

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)

			let socketURL = try self.options.vmnetEndpoint(runMode: self.common.runMode)

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
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.start(options: self.options, runMode: self.common.runMode)))
		}
	}

	struct Stop: ParsableCommand {
		static let configuration = NetworkStopOptions.configuration

		@OptionGroup(title: "Global options")
		var common: CommonOptions

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
				try Networks.validateNetwork(networkName: networkName, runMode: self.common.runMode)
			} else if let pidFile {
				if !FileManager.default.fileExists(atPath: pidFile) {
					throw ValidationError("PID file \(pidFile) does not exist")
				}
			}
		}

		func run() throws {
			if let pidFile {
				Logger.appendNewLine(self.common.format.render(try NetworksHandler.stop(pidURL: URL(fileURLWithPath: pidFile), runMode: self.common.runMode)))
			} else if let networkName {
				Logger.appendNewLine(self.common.format.render(try NetworksHandler.stop(networkName: networkName, runMode: self.common.runMode)))
			} else {
				throw ValidationError("No network name provided")
			}
		}
	}

	struct List: ParsableCommand {
		static let configuration = NetworkListOptions.configuration

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try NetworksHandler.networks(runMode: self.common.runMode)))
		}
	}
}
