import ArgumentParser
import Foundation
import GRPCLib
import Virtualization
import NIOCore
import TextTable
import NIOPosix
import Logging
import vmnet
import SystemConfiguration

extension Caked_CreateNetworkRequest {
	func toVZSharedNetwork() -> VZSharedNetwork {
		return VZSharedNetwork(
			netmask: self.netmask,
			dhcpStart: self.gateway,
			dhcpEnd: self.dhcpEnd,
			dhcpLease: self.hasDhcpLease ? self.dhcpLease : nil,
			uuid: self.hasUuid ? self.uuid : nil,
			nat66Prefix: self.hasNat66Prefix ? self.nat66Prefix : nil
		)
	}
}

extension Caked_ConfigureNetworkRequest {
	func toUsedNetworkConfig() -> UsedNetworkConfig {
		return UsedNetworkConfig(
			networkName: self.name,
			netmask: self.hasNetmask ? self.netmask : nil,
			dhcpStart: self.hasGateway ? self.gateway : nil,
			dhcpEnd: self.hasDhcpEnd ? self.dhcpEnd : nil,
			dhcpLease: self.hasDhcpLease ? self.dhcpLease : nil,
			uuid: self.hasUuid ? self.uuid : nil,
			nat66Prefix: self.hasNat66Prefix ? self.nat66Prefix : nil
		)
	}
}

enum VMNetMode: uint64, CaseIterable, ExpressibleByArgument, Codable {
	var defaultValueDescription: String { "host" }

	static let allValueStrings: [String] = VMNetMode.allCases.map { "\($0)" }

	case host = 1000
	case shared = 1001
	case bridged = 1002

	init?(argument: String) {
		switch argument {
		case "host":
			self = .host
		case "shared":
			self = .shared
		case "bridged":
			self = .bridged
		default:
			return nil
		}
	}

	var stringValue: String {
		switch self {
		case .host:
			return "host"
		case .shared:
			return "shared"
		case .bridged:
			return "bridged"
		}
	}
}

struct UsedNetworkConfig {
	var networkName: String
	var netmask: String? = nil
	var dhcpStart: String? = nil
	var dhcpEnd: String? = nil
	var dhcpLease: Int32? = nil
	var uuid: String? = UUID().uuidString
	var nat66Prefix: String? = nil

	init(networkName: String, netmask: String?, dhcpStart: String?, dhcpEnd: String?, dhcpLease: Int32?, uuid: String? = nil, nat66Prefix: String? = nil) {
		self.networkName = networkName
		self.netmask = netmask
		self.dhcpStart = dhcpStart
		self.dhcpEnd = dhcpEnd
		self.dhcpLease = dhcpLease
		self.uuid = uuid
		self.nat66Prefix = nat66Prefix
	}

	init(name: String, config: VZSharedNetwork? = nil) {
		self.networkName = name
		self.netmask = config?.netmask
		self.dhcpStart = config?.dhcpStart
		self.dhcpEnd = config?.dhcpEnd
		self.dhcpLease = config?.dhcpLease
		self.uuid = config?.uuid
		self.nat66Prefix = config?.nat66Prefix
	}
}

struct BridgedNetwork: Codable {
	var name: String
	var description: String = ""
	var gateway: String = ""
	var dhcpEnd = ""
	var interfaceID: String = ""
	var endpoint: String = ""
}

struct NetworksHandler: CakedCommandAsync {
	var request: Caked_NetworkRequest

	struct VMNetOptions: ParsableArguments {
		@Flag(name: [.customLong("system"), .customShort("s")], help: "Run caked as system agent, need sudo")
		var asSystem: Bool = false

		@Flag(help: .hidden)
		var debug: Bool = false

		@Argument(help: "socket path")
		var socketPath: String? = nil

		@Option(name: [.customLong("fd")], help: "Use file descriptor for VMNet")
		var vmfd: Int? = nil

		@Option(name: [.customLong("socket-group")], help: "socket group name")
		var socketGroup: String = "staff"

		@Option(name: [.customLong("mode")], help: "vmnet mode")
		var mode = VMNetMode.bridged

		@Option(name: [.customLong("interface")], help: ArgumentHelp("interface\n", discussion: "interface used for --vmnet=bridged, e.g., \"en0\""))
		var networkName: String = ""

		@Option(name: [.customLong("mac-address")], help: ArgumentHelp("Mac Address of VM\n", discussion: "Mac address configured for VM network interface"))
		var macAddress: String? = nil

		@Option(name: [.customLong("gateway")], help: ArgumentHelp("IP gateway\n", discussion: "gateway used for --vmnet=(host|shared), e.g., \"192.168.105.1\" (default: decided by macOS)"))
		var gateway: String? = nil

		@Option(name: [.customLong("dhcp-end")], help: "end of the DHCP range")
		var dhcpEnd: String? = nil

		@Option(help: "DHCP lease time in seconds")
		var dhcpLease: Int32? = nil

		@Option(name: [.customLong("netmask")], help: ArgumentHelp("subnet mask\n", discussion: "requires --gateway to be specified"))
		var subnetMask = "255.255.255.0"

		@Option(name: [.customLong("interface-id")], help: ArgumentHelp("vmnet interface ID\n", discussion: "randomly generated if not specified"))
		var interfaceID = UUID().uuidString

		@Option(name: [.customLong("nat66-prefix")], help: "The IPv6 prefix to use with shared mode")
		var nat66Prefix: String? = nil

		@Option(name: [.customLong("pidfile")], help: "save pid to PIDFILE")
		var pidFile: String? = nil

		init() {

		}

		init(networkName: String, asSystem: Bool) throws {
			self.networkName = networkName

			self.asSystem = asSystem
			self.debug = false
			self.networkName = networkName
			self.socketGroup = "staff"
			self.socketPath = nil
			self.vmfd = nil
			self.pidFile = nil

			if NetworksHandler.isPhysicalInterface(name: networkName) {
				self.mode = .bridged
				self.gateway = nil
				self.dhcpEnd = nil
				self.dhcpLease = nil
				self.subnetMask = "255.255.255.0"
				self.interfaceID = UUID().uuidString
				self.nat66Prefix = nil
			} else {
				self.mode = .shared

				let home: Home = try Home(asSystem: runAsSystem)
				let networkConfig = try home.sharedNetworks()

				guard let network = networkConfig.sharedNetworks[networkName] else {
					throw ServiceError("Network \(networkName) doesn't exists")
				}

				self.gateway = network.dhcpStart
				self.dhcpEnd = network.dhcpEnd
				self.dhcpLease = network.dhcpLease
				self.subnetMask = network.netmask
				self.interfaceID = network.uuid ?? UUID().uuidString
				self.nat66Prefix = network.nat66Prefix
			}
		}

		func validate() throws {
			runAsSystem = self.asSystem

			if self.vmfd != nil && self.socketPath != nil {
				throw ValidationError("fd and socket-path are mutually exclusive \(self.vmfd!) \(self.socketPath!)")
			}

			if let vmfd = self.vmfd {
				if self.pidFile == nil {
					throw ValidationError("pidfile is required when using fd")
				}

				if self.macAddress == nil {
					throw ValidationError("mac-address is required when using fd")
				}

				guard fcntl(Int32(vmfd), F_GETFD) != -1 || errno != EBADF else {
					throw ValidationError("File descriptor is not open")
				}
			}

			if self.mode == .bridged {
				if self.networkName == "" {
					throw ValidationError("interface is required for bridged mode")
				}

				if self.gateway != nil {
					throw ValidationError("gateway is not allowed for bridged mode")
				}

				if self.dhcpEnd != nil {
					throw ValidationError("dhcp-end is not allowed for bridged mode")
				}
			} else if let gateway = self.gateway {
				guard let gatewayAddr = IP.V4(gateway) else {
					throw ValidationError("gateway is not a valid IP address")
				}

				guard let dhcpEnd = self.dhcpEnd else {
					throw ValidationError("dhcp-end is required for host/shared mode when gateway is specified")
				}

				guard let dhcpEndAddr = IP.V4(dhcpEnd) else {
					throw ValidationError("dhcp-end is not a valid IP address")
				}

				guard self.subnetMask.isValidNetmask() else {
					throw ValidationError("valid netmask is required for host/shared mode when gateway is specified")
				}

				let cidr = self.subnetMask.netmaskToCidr()
				let network = IP.Block<IP.V4>(base: gatewayAddr, bits: UInt8(cidr)).network

				if network.contains(dhcpEndAddr) == false {
					throw ValidationError("dhcp-end is not in the same network as gateway")
				}
			}
		}

		func createVZVMNet() throws -> (URL, VZVMNet) {
			guard let vmfd = self.vmfd else {
				let socketURL: (URL, URL)

				guard let grp = getgrnam(self.socketGroup) else {
					throw ServiceError("Failed to get group \(self.socketGroup)")
				}

				if let socketPath = self.socketPath, let pidFile = self.pidFile {
					socketURL = (URL(fileURLWithPath: socketPath), URL(fileURLWithPath: pidFile))
				} else {
					socketURL = try NetworksHandler.vmnetEndpoint(networkName: self.networkName, asSystem: self.asSystem)
				}

				if let dhcpLease = self.dhcpLease {
					try NetworksHandler.setDHCPLease(leaseTime: dhcpLease)
				}

				if try socketURL.0.exists() == false {
					let vzvmnet = VZVMNetSocket(
						on: Root.group.next(),
						socketPath: socketURL.0,
						socketGroup: grp.pointee.gr_gid,
						mode: self.mode,
						networkInterface: self.networkName,
						gateway: self.gateway,
						dhcpEnd: self.dhcpEnd,
						subnetMask: self.subnetMask,
						interfaceID: self.interfaceID,
						nat66Prefix: self.nat66Prefix,
						pidFile: socketURL.1
					)

					return (socketURL.1, vzvmnet)
				} else {
					throw ServiceError("Socket file already exists at \(socketURL.0.path)")
				}
			}

			guard let pidFile = self.pidFile else {
				throw ServiceError("pidfile is required when using vmfd")
			}

			let pidUrl = URL(fileURLWithPath: pidFile)

			try? pidUrl.delete()

			let vzvmnet = VZVMNetFileHandle(on: Root.group.next(),
			                                inputOutput: CInt(vmfd),
			                                mode: self.mode,
			                                networkInterface: self.networkName,
			                                macAddress: self.macAddress!,
			                                gateway: self.gateway,
			                                dhcpEnd: self.dhcpEnd,
			                                subnetMask: self.subnetMask,
			                                interfaceID: self.interfaceID,
			                                nat66Prefix: self.nat66Prefix,
			                                pidFile: pidUrl)

			return (pidUrl, vzvmnet)
		}
	}

	static func setDHCPLease(leaseTime: Int32) throws {
		guard let ref = SCPreferencesCreate(nil, "caked" as CFString, "com.apple.InternetSharing.default.plist" as CFString) else {
			throw ServiceError("Unable to create SCPreferences")
		}

		Logger(self).info("Set DHCP lease time to \(leaseTime) seconds")

		let lease = [
			"DHCPLeaseTimeSecs" as CFString: leaseTime as CFNumber,
		] as CFDictionary

		SCPreferencesSetValue(ref, "bootpd" as CFString, lease)
		SCPreferencesCommitChanges(ref)
		SCPreferencesApplyChanges(ref)
	}

	static func isPhysicalInterface(name: String) -> Bool {
		let interfaces = VZBridgedNetworkInterface.networkInterfaces

		for interface in interfaces {
			if interface.identifier == name {
				return true
			}
		}

		return false
	}

	static func vmnetEndpoint(networkName: String, asSystem: Bool) throws -> (URL, URL) {
		let createIfNotExists: Bool = asSystem ? geteuid() == 0 : true
		let home = try Home.init(asSystem: asSystem, createItIfNotExists: createIfNotExists)
		let networkDirectory = home.networkDirectory.appendingPathComponent(networkName, isDirectory: true)

		if try networkDirectory.exists() == false && createIfNotExists {
			try FileManager.default.createDirectory(at: networkDirectory, withIntermediateDirectories: true)
		}

		return (networkDirectory.appendingPathComponent("vmnet.sock").absoluteURL, networkDirectory.appendingPathComponent("vmnet.pid").absoluteURL)
	}

	// Must be run as root
	static func restartNetworkService(networkName: String, asSystem: Bool) throws {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, asSystem: asSystem)
		let pidURL = socketURL.1

		guard pidURL.isPIDRunning() else {
			Logger(self).info("Network \(networkName) is not running")
			return
		}

		Logger(self).info("Restart network \(networkName)")

		if geteuid() == 0 {
			if pidURL.killPID(SIGUSR2) < 0 {
				throw ServiceError("Failed to kill process \(pidURL.path): \(String(cString: strerror(errno)))")
			} else {
				Logger(self).info("Network \(networkName) restarted")
			}
		} else {
			guard let executableURL = URL.binary("caked") else {
				throw ServiceError("caked not found in path")
			}

			guard try checkIfSudoable(binary: executableURL) else {
				throw ServiceError("\(executableURL.lastPathComponent) is not sudoable")
			}

			// We are not running as root, so we need to use sudo to kill the process
			guard let sudoURL = URL.binary("sudo") else {
				throw ServiceError("sudo not found in path")
			}

			let process = Process()

			process.executableURL = sudoURL
			process.arguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--", "pkill", "-SIGUSR2", "-F", "\(pidURL.path)"]
			process.environment = try Root.environment()
			process.standardInput = FileHandle.standardInput
			process.standardOutput = FileHandle.standardOutput
			process.standardError = FileHandle.standardError

			try process.run()

			process.waitUntilExit()

			if process.terminationStatus != 0 {
				throw ServiceError("Failed to kill process \(pidURL.path): \(String(cString: strerror(process.terminationStatus)))")
			} else {
				Logger(self).info("Network \(networkName) restarted")
			}
		}
	}

	static func startNetworkService(networkName: String) throws {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, asSystem: runAsSystem)

		if socketURL.1.isPIDRunning() {
			Logger(self).info("Network \(networkName) is already running")
			return
		}

		_ = try Self.start(networkName: networkName, asSystem: runAsSystem)
	}

	static func checkIfSudoable(binary: URL) throws -> Bool {
		if geteuid() == 0 {
			return true
		}

		guard let sudoURL = URL.binary("sudo") else {
			throw ServiceError("sudo not found in path")
		}

		let info = try FileManager.default.attributesOfItem(atPath: binary.path) as NSDictionary

		if info.fileOwnerAccountID() == 0 && (info.filePosixPermissions() & Int(S_ISUID)) != 0 {
			return true
		}

		let process = Process()

		process.executableURL = sudoURL
		process.environment = try Root.environment()
		process.arguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--",binary.path, "--help"]
		process.standardInput = nil
		process.standardOutput = nil
		process.standardError = nil

		try process.run()

		process.waitUntilExit()

		if process.terminationStatus == 0 {
			return true
		}

		return false
	}

	static func run(fileDescriptor: Int32, mode: VMNetMode, macAddress: String? = nil, networkConfig: UsedNetworkConfig, pidFile: URL) throws -> ProcessWithSharedFileHandle {
		Logger(self).info("Start VMNet mode: \(mode.stringValue) Using vmfd: \(fileDescriptor)")

		guard let executableURL = URL.binary(phUseLimaVMNet ? "sock-vmnet" : "caked") else {
			throw ServiceError("caked not found in path")
		}

		var arguments: [String] = []
		var runningArguments: [String]
		let process = ProcessWithSharedFileHandle()

		if phUseLimaVMNet == false {
			arguments.append(contentsOf: [ "networks", "run" ])
		}

		if Logger.LoggingLevel() > .info {
			arguments.append("--log-level=\(Logger.LoggingLevel().rawValue)")
		}

		arguments.append("--mode=\(mode.stringValue)")

		if Logger.Level() >= .debug {
			arguments.append("--debug")
		}

		if let interfaceID = networkConfig.uuid {
			arguments.append("--interface-id=\(interfaceID)")
		}

		if let macAddress = macAddress {
			arguments.append("--mac-address=\(macAddress)")
		}

		if mode == .bridged {
			guard networkConfig.networkName != "" else {
				throw ServiceError("interface is required for bridged mode")
			}
			arguments.append("--interface=\(networkConfig.networkName)")
		} else {
			if let dhcpStart = networkConfig.dhcpStart {
				arguments.append("--gateway=\(dhcpStart)")
			}

			if let dhcpEnd = networkConfig.dhcpEnd {
				arguments.append("--dhcp-end=\(dhcpEnd)")
			}

			if let netmask = networkConfig.netmask {
				arguments.append("--netmask=\(netmask)")
			}

			if let nat66Prefix = networkConfig.nat66Prefix {
				arguments.append("--nat66-prefix=\(nat66Prefix)")
			}
		}

		var fd = fileDescriptor

		if geteuid() == 0 {
			runningArguments = []
			process.executableURL = executableURL
			process.standardInput = FileHandle.standardInput
			process.sharedFileHandles = [FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: false)]
		} else {
			guard let sudoURL = URL.binary("sudo") else {
				throw ServiceError("sudo not found in path")
			}

			guard try checkIfSudoable(binary: executableURL) else {
				throw ServiceError("\(executableURL.lastPathComponent) is not sudoable")
			}

			fd = STDIN_FILENO
			// We need to use the file descriptor of stdin, otherwise the process will not be able to read from it
			// and will block forever
			runningArguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--", executableURL.absoluteURL.path]
			process.executableURL = sudoURL
			process.standardInput = FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: false)
		}

		arguments.append("--pidfile=\(pidFile.absoluteURL.path)")
		arguments.append("--fd=\(fd)")

		runningArguments.append(contentsOf: arguments)
		Logger(self).info("Running: \(process.executableURL!.path) \(runningArguments.joined(separator: " "))")

		try? pidFile.delete()

		process.arguments = runningArguments
		process.environment = try Root.environment()
		process.standardOutput = FileHandle.standardOutput
		process.standardError = FileHandle.standardError
		process.terminationHandler = { process in
			Logger(self).info("Process died: \(process.terminationStatus), \(process.terminationReason)")
			kill(getpid(), SIGUSR2)
		}

		try process.run()
		try pidFile.waitPID {
			if process.isRunning == false {
				if process.terminationReason == .uncaughtSignal {
					throw ServiceError("Network \(networkConfig.networkName) failed to start: \(process.terminationStatus), \(process.terminationReason)")
				} else {
					throw ServiceError("Network \(networkConfig.networkName) stopped: \(process.terminationStatus)")
				}
			}
		}

		return process
	}

	static func run(useLimaVMNet: Bool = false, mode: VMNetMode, networkConfig: UsedNetworkConfig, socketPath: URL? = nil, pidFile: URL? = nil) throws {
		let socketURL: (URL, URL)
		let executableURL: URL
		let debug = Logger.Level() >= .debug
		var arguments: [String] = []

		if let socketPath = socketPath, let pidFile = pidFile {
			socketURL = (socketPath, pidFile)
		} else {
			socketURL = try NetworksHandler.vmnetEndpoint(networkName: networkConfig.networkName, asSystem: runAsSystem)
		}

		Logger(self).info("Start VMNet mode: \(mode.stringValue) Using socket: \(socketURL.0.path)")

		if useLimaVMNet {

			guard let socket_vmnet = URL.binary("socket_vmnet") else {
				throw ServiceError("socket_vmnet not found in path")
			}

			executableURL = socket_vmnet

			//if Logger.Level() >= .debug {
			//	arguments.append("--debug")
			//}

			//arguments.append("--vmnet-vz")
			arguments.append("--vmnet-mode=\(mode.stringValue)")

			if mode == .bridged {
				guard networkConfig.networkName != "" else {
					throw ServiceError("interface is required for bridged mode")
				}
				arguments.append("--vmnet-interface=\(networkConfig.networkName)")
			} else {
				if let dhcpStart = networkConfig.dhcpStart {
					arguments.append("--vmnet-gateway=\(dhcpStart)")
				}
				if let dhcpEnd = networkConfig.dhcpEnd {
					arguments.append("--vmnet-dhcp-end=\(dhcpEnd)")
				}
				if let netmask = networkConfig.netmask {
					arguments.append("--vmnet-mask=\(netmask)")
				}
				if let interfaceID = networkConfig.uuid {
					arguments.append("--vmnet-interface-id=\(interfaceID)")
				}
				if let nat66Prefix = networkConfig.nat66Prefix {
					arguments.append("--vmnet-nat66-prefix=\(nat66Prefix)")
				}
			}

			arguments.append("--pidfile=\(socketURL.1.absoluteURL.path)")
			arguments.append(socketURL.0.absoluteURL.path)
		} else if let caker = URL.binary("caked") {
			executableURL = caker

			arguments.append(contentsOf: ["networks", "run", "--mode=\(mode.stringValue)"])

			if Logger.LoggingLevel() > .info {
				arguments.append("--log-level=\(Logger.LoggingLevel().rawValue)")
			}

			if runAsSystem {
				arguments.append("--system")
			}

			if let interfaceID = networkConfig.uuid {
				arguments.append("--interface-id=\(interfaceID)")
			}

			if mode == .bridged {
				guard networkConfig.networkName != "" else {
					throw ServiceError("interface is required for bridged mode")
				}
				arguments.append("--interface=\(networkConfig.networkName)")
			} else {
				if let dhcpStart = networkConfig.dhcpStart {
					arguments.append("--gateway=\(dhcpStart)")
				}

				if let dhcpEnd = networkConfig.dhcpEnd {
					arguments.append("--dhcp-end=\(dhcpEnd)")
				}

				if let netmask = networkConfig.netmask {
					arguments.append("--netmask=\(netmask)")
				}

				if let nat66Prefix = networkConfig.nat66Prefix {
					arguments.append("--nat66-prefix=\(nat66Prefix)")
				}
			}

			arguments.append("--pidfile=\(socketURL.1.absoluteURL.path)")
			arguments.append(socketURL.0.absoluteURL.path)
		} else {
			throw ServiceError("caked not found in path")
		}

		if socketURL.1.isPIDRunning() {
			throw ServiceError("\(executableURL.path) is already running")
		}

		try? socketURL.0.delete()

		let process = Process()
		var runningArguments: [String]

		if geteuid() == 0 {
			process.executableURL = executableURL
			runningArguments = []
		} else {
			guard let sudoURL = URL.binary("sudo") else {
				throw ServiceError("sudo not found in path")
			}

			guard try checkIfSudoable(binary: executableURL) else {
				throw ServiceError("\(executableURL.lastPathComponent) is not sudoable")
			}

			process.executableURL = sudoURL

			runningArguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--", executableURL.absoluteURL.path]
		}

		runningArguments.append(contentsOf: arguments)

		Logger(self).info("Running: \(process.executableURL!.path) \(runningArguments.joined(separator: " "))")

		process.arguments = runningArguments
		process.environment = try Root.environment()
		process.standardInput = FileHandle.nullDevice
		process.standardOutput = debug ? FileHandle.standardOutput : FileHandle.nullDevice
		process.standardError = debug ? FileHandle.standardError : FileHandle.nullDevice
		process.terminationHandler = { process in
			Logger(self).info("Process terminated: \(process.terminationStatus), \(process.terminationReason)")
			kill(getpid(), SIGUSR2)
		}

		try process.run()
		try socketURL.1.waitPID {
			if process.isRunning == false {
				if process.terminationReason == .uncaughtSignal {
					throw ServiceError("Network \(networkConfig.networkName) failed to start: \(process.terminationStatus), \(process.terminationReason)")
				} else {
					throw ServiceError("Network \(networkConfig.networkName) stopped: \(process.terminationStatus)")
				}
			}
		}
	}

	static func configure(networkName: String, network: VZSharedNetwork, asSystem: Bool) throws -> String {
		let home: Home = try Home(asSystem: runAsSystem)
		var networkConfig = try home.sharedNetworks()

		guard let existing = networkConfig.sharedNetworks[networkName] else {
			throw ServiceError("Network \(networkName) doesn't exists")
		}

		if existing == network {
			return "Network \(networkName) unchanged"
		}

		networkConfig.sharedNetworks[networkName] = network

		try home.setSharedNetworks(networkConfig)
		try self.restartNetworkService(networkName: networkName, asSystem: asSystem)

		return "Network \(networkName) reconfigured"
	}

	static func configure(network: UsedNetworkConfig, asSystem: Bool) throws -> String {
		let home: Home = try Home(asSystem: runAsSystem)
		var networkConfig = try home.sharedNetworks()

		guard network.networkName != "" else {
			throw ServiceError("Network name is required")
		}

		guard Self.isPhysicalInterface(name: String(network.networkName)) == false else {
			throw ServiceError("Network \(network.networkName) is a physical interface")
		}

		guard let exisiting = networkConfig.sharedNetworks[network.networkName] else {
			throw ServiceError("Network \(network.networkName) doesn't exists")
		}

		let changed = VZSharedNetwork(
			netmask: network.netmask ?? exisiting.netmask,
			dhcpStart: network.dhcpStart ?? exisiting.dhcpStart,
			dhcpEnd: network.dhcpEnd ?? exisiting.dhcpEnd,
			dhcpLease: network.dhcpLease ?? exisiting.dhcpLease,
			uuid: network.uuid ?? exisiting.uuid,
			nat66Prefix: network.nat66Prefix ?? exisiting.nat66Prefix
		)
print(network)
print(changed)
print(exisiting)

		if changed != exisiting {
			try changed.validate()
			networkConfig.sharedNetworks[network.networkName] = changed
			try home.setSharedNetworks(networkConfig)
			try self.restartNetworkService(networkName: network.networkName, asSystem: asSystem)
		
			return "Network \(network.networkName) configured"
		} else {
			return "Network \(network.networkName) unchanged"
		}
	}

	static func start(networkName: String, asSystem: Bool) throws -> (URL, URL) {
		let home: Home = try Home(asSystem: runAsSystem)
		let sharedNetworks = try home.sharedNetworks().sharedNetworks
		let socketURL: (URL, URL)

		if Self.isPhysicalInterface(name: networkName) {
			socketURL = try Self.vmnetEndpoint(networkName: networkName, asSystem: asSystem)
		} else {
			guard let sharedNetwork = sharedNetworks[networkName] else {
				throw ServiceError("Network \(networkName) doesn't exists")
			}

			try sharedNetwork.validate()

			socketURL = try Self.vmnetEndpoint(networkName: networkName, asSystem: asSystem)
		}

		if socketURL.1.isPIDRunning() {
			throw ServiceError("Network \(networkName) already running \(socketURL.1.path)")
		}

		Logger(self).info("Start network: \(networkName) Using socket: \(socketURL.0.path)")

		guard let executableURL = URL.binary("caked") else {
			throw ServiceError("caked not found in path")
		}

		var arguments = ["networks", "start", networkName]
		let process = Process()
		var runningArguments: [String]
		let debug = Logger.Level() >= .debug

		if Logger.LoggingLevel() > .info {
			arguments.append("--log-level=\(Logger.LoggingLevel().rawValue)")
		}

		if runAsSystem {
			arguments.append("--system")
		}

		try? socketURL.0.delete()

		if geteuid() == 0 {
			process.executableURL = executableURL
			runningArguments = []
		} else {
			guard let sudoURL = URL.binary("sudo") else {
				throw ServiceError("sudo not found in path")
			}

			guard try checkIfSudoable(binary: executableURL) else {
				throw ServiceError("\(executableURL.lastPathComponent) is not sudoable")
			}

			process.executableURL = sudoURL

			runningArguments = ["--non-interactive", "--preserve-env=CAKE_HOME", executableURL.absoluteURL.path]
		}

		runningArguments.append(contentsOf: arguments)

		Logger(self).info("Running: \(process.executableURL!.path) \(runningArguments.joined(separator: " "))")

		process.arguments = runningArguments
		process.environment = try Root.environment()
		process.standardInput = FileHandle.nullDevice
		process.standardOutput = debug ? FileHandle.standardOutput : FileHandle.nullDevice
		process.standardError = debug ? FileHandle.standardError : FileHandle.nullDevice
		process.terminationHandler = { process in
			if process.terminationReason == .uncaughtSignal {
				Logger(self).info("Network \(networkName) terminated: \(process.terminationStatus), \(process.terminationReason)")
			} else {
				Logger(self).info("Network \(networkName) exited: \(process.terminationStatus)")
			}
		}

		try process.run()
		try socketURL.1.waitPID {
			if process.isRunning == false {
				if process.terminationReason == .uncaughtSignal {
					throw ServiceError("Network \(networkName) failed to start: \(process.terminationStatus), \(process.terminationReason)")
				} else {
					throw ServiceError("Network \(networkName) stopped: \(process.terminationStatus)")
				}
			}
		}

		return socketURL
	}

	static func run(networkName: String, asSystem: Bool) throws -> (URL, URL) {
		let home: Home = try Home(asSystem: runAsSystem)
		let sharedNetworks = try home.sharedNetworks().sharedNetworks
		let socketURL: (URL, URL)
		let mode: VMNetMode
		let networkConfig: UsedNetworkConfig

		if Self.isPhysicalInterface(name: networkName) {
			socketURL = try Self.vmnetEndpoint(networkName: networkName, asSystem: asSystem)
			mode = .bridged
			networkConfig = .init(name: networkName)
		} else {
			guard let network = sharedNetworks[networkName] else {
				throw ServiceError("Network \(networkName) doesn't exists")
			}

			mode = networkName == "host" ? .host : .shared
			socketURL = try Self.vmnetEndpoint(networkName: networkName, asSystem: asSystem)
			networkConfig = UsedNetworkConfig(name: networkName, config: network)
		}

		try Self.run(mode: mode, networkConfig: networkConfig, socketPath: socketURL.0, pidFile: socketURL.1)

		return socketURL
	}

	static func create(networkName: String, network: VZSharedNetwork, asSystem: Bool) throws -> String {
		let home: Home = try Home(asSystem: runAsSystem)
		var networkConfig = try home.sharedNetworks()

		if networkConfig.sharedNetworks[networkName] != nil {
			throw ServiceError("Network \(networkName) already exists")
		}

		networkConfig.sharedNetworks[networkName] = network

		try home.setSharedNetworks(networkConfig)

		return "Network \(networkName) created"
	}

	static func delete(networkName: String, asSystem: Bool) throws -> String {
		let home: Home = try Home(asSystem: runAsSystem)
		var networkConfig = try home.sharedNetworks()

		if networkConfig.sharedNetworks[networkName] == nil {
			throw ServiceError("Network \(networkName) doesn't exists")
		}

		networkConfig.sharedNetworks.removeValue(forKey: networkName)

		try home.setSharedNetworks(networkConfig)

		return "Network \(networkName) deleted"
	}

	static func start(options: NetworksHandler.VMNetOptions) throws {
		let vzvmnet = try options.createVZVMNet()
		var signalReconfigure: DispatchSourceSignal? = nil

		if NetworksHandler.isPhysicalInterface(name: options.networkName) == false {
			let sig = DispatchSource.makeSignalSource(signal: SIGUSR2)

			if let dhcpLease = options.dhcpLease {
				try NetworksHandler.setDHCPLease(leaseTime: dhcpLease)
			}

			Logger(self).info("Allow reconfigure network: \(options.networkName)")

			signal(SIGUSR2, SIG_IGN)

			sig.setEventHandler {
				Logger(self).info("Will reconfigure network: \(options.networkName)")

				do {
					let reconfigureOption = try NetworksHandler.VMNetOptions(networkName: options.networkName, asSystem: false)

					if let dhcpLease = options.dhcpLease {
						try NetworksHandler.setDHCPLease(leaseTime: dhcpLease)
					}

					try? vzvmnet.1.reconfigure(gateway: reconfigureOption.gateway!,
					                           dhcpEnd: reconfigureOption.dhcpEnd!,
					                           subnetMask: reconfigureOption.subnetMask,
					                           interfaceID: reconfigureOption.interfaceID,
					                           nat66Prefix: reconfigureOption.nat66Prefix)
				} catch {
					Logger(self).error("Failed to reconfigure network: \(error)")
					Foundation.exit(1)
				}
			}

			sig.activate()
			signalReconfigure = sig
		}

		defer {
			if let sig = signalReconfigure {
				sig.cancel()
			}
		}

		try vzvmnet.1.start()
	}

	static func stop(networkName: String, asSystem: Bool) throws -> String {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, asSystem: asSystem)
		let pidURL = socketURL.1

		guard pidURL.isPIDRunning() else {
			Logger(self).info("Network \(networkName) is not running")
			return "Network \(networkName) is not running"
		}

		if geteuid() == 0 {
			// We are running as root, so we can just kill the process
			if pidURL.killPID(SIGTERM) < 0 {
				throw ServiceError("Failed to kill process \(pidURL.path): \(String(cString: strerror(errno)))")
			} else {
				Logger(self).info("Network \(networkName) stopped")
			}
		} else {
			guard let executableURL = URL.binary("caked") else {
				throw ServiceError("caked not found in path")
			}

			guard try checkIfSudoable(binary: executableURL) else {
				throw ServiceError("\(executableURL.lastPathComponent) is not sudoable")
			}

			// We are not running as root, so we need to use sudo to kill the process
			guard let sudoURL = URL.binary("sudo") else {
				throw ServiceError("sudo not found in path")
			}

			let process = Process()

			process.executableURL = sudoURL
			process.arguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--", "pkill", "-TERM", "-F", "\(pidURL.path)"]
			process.environment = try Root.environment()
			process.standardInput = FileHandle.nullDevice
			process.standardOutput = FileHandle.nullDevice
			process.standardError = FileHandle.nullDevice

			try process.run()

			process.waitUntilExit()

			if process.terminationStatus != 0 {
				throw ServiceError("Failed to kill process \(pidURL.path): \(String(cString: strerror(process.terminationStatus)))")
			} else {
				Logger(self).info("Network \(networkName) stopped")
			}
		}

		return "Network \(networkName) stopped"
	}

	static func networks(asSystem: Bool) throws -> [BridgedNetwork] {
		var networks: [BridgedNetwork] = [BridgedNetwork(name: "nat", description: "NAT shared network", interfaceID: "nat", endpoint: "")]
		let home: Home = try Home(asSystem: runAsSystem)
		let networkConfig = try home.sharedNetworks()

		let createBridgedNetwork: (_ name: String, _ description: String, _ uuid: String, _ gateway: String, _ dhcpEnd: String) throws -> BridgedNetwork = { (name, description, uuid, gateway, dhcpEnd) in
			let socketURL = try NetworksHandler.vmnetEndpoint(networkName: name, asSystem: asSystem)
			let endpoint: String

			if try socketURL.0.exists() {
				endpoint = socketURL.0.absoluteURL.path
			} else {
				endpoint = "not running"
			}

			return BridgedNetwork(name: name, description: description, gateway: gateway, dhcpEnd: dhcpEnd, interfaceID: uuid, endpoint: endpoint)
		}

		try networks.append(contentsOf: VZBridgedNetworkInterface.networkInterfaces.map { inf in
			return try createBridgedNetwork(inf.identifier, inf.localizedDisplayName ?? inf.identifier, "", "", "")
		})

		return try networkConfig.sharedNetworks.reduce(into: networks) {
			let cidr = $1.value.netmask.netmaskToCidr()
			let gateway = "\($1.value.dhcpStart)/\(cidr)"
			let dhcpEnd = "\($1.value.dhcpEnd)/\(cidr)"
			let uuid = $1.value.uuid ?? ""


			$0.append(try createBridgedNetwork($1.key, "Shared network", uuid, gateway, dhcpEnd))
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		on.submit {
			let format: Format = self.request.format == .text ? .text : .json
			let message: String

			switch self.request.command {
			case .infos:
				return format.renderList(style: Style.grid, uppercased: true, try Self.networks(asSystem: asSystem))
			case .create:
				message = try Self.create(networkName: self.request.create.name, network: self.request.create.toVZSharedNetwork(), asSystem: asSystem)
			case .remove:
				message = try Self.delete(networkName: self.request.name, asSystem: asSystem)
			case .start:
				_ = try Self.start(networkName: self.request.name, asSystem: asSystem)
				message = "Network \(self.request.name) started"
			case .shutdown:
				message = try Self.stop(networkName: self.request.name, asSystem: asSystem)
			case .configure:
				message = try Self.configure(network: self.request.configure.toUsedNetworkConfig(), asSystem: asSystem)
			default:
				throw ServiceError("Unknown command")
			}

			if self.request.format == .json {
				return format.renderSingle(style: Style.grid, uppercased: true, message)
			} else {
				return message
			}
		}
	}
}
