import ArgumentParser
import Foundation
import GRPCLib
import Virtualization
import NIOCore
import TextTable
import NIOPosix
import Logging
import vmnet

extension Caked_CreateNetworkRequest {
	func toVZSharedNetwork() -> VZSharedNetwork {
		return VZSharedNetwork(
			netmask: self.netmask,
			dhcpStart: self.gateway,
			dhcpEnd: self.dhcpEnd,
			uuid: self.uuid,
			nat66Prefix: self.nat66Prefix
		)
	}
}

extension Caked_ConfigureNetworkRequest {
	func toUsedNetworkConfig() -> UsedNetworkConfig {
		return UsedNetworkConfig(
			networkName: self.name,
			netmask: self.netmask,
			dhcpStart: self.gateway,
			dhcpEnd: self.dhcpEnd,
			uuid: self.uuid,
			nat66Prefix: self.nat66Prefix
		)
	}
}

enum VMNetMode: uint64, CaseIterable, ExpressibleByArgument, Codable {
	var defaultValueDescription: String { "host" }

	static var allValueStrings: [String] = VMNetMode.allCases.map { "\($0)" }

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
	var networkName: String? = nil
	var netmask: String? = nil
	var dhcpStart: String? = nil
	var dhcpEnd: String? = nil
	var uuid: String? = UUID().uuidString
	var nat66Prefix: String? = nil

	init(networkName: String, netmask: String?, dhcpStart: String?, dhcpEnd: String?, uuid: String? = nil, nat66Prefix: String? = nil) {
		self.networkName = networkName
		self.netmask = netmask
		self.dhcpStart = dhcpStart
		self.dhcpEnd = dhcpEnd
		self.uuid = uuid ?? UUID().uuidString
		self.nat66Prefix = nat66Prefix
	}

	init(name: String, config: VZSharedNetwork? = nil) {
		self.networkName = name
		self.netmask = config?.netmask
		self.dhcpStart = config?.dhcpStart
		self.dhcpEnd = config?.dhcpEnd
		self.uuid = config?.uuid ?? UUID().uuidString
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
		var networkName: String? = nil

		@Option(name: [.customLong("mac-address")], help: ArgumentHelp("Mac Address of VM\n", discussion: "Mac address configured for VM network interface"))
		var macAddress: String? = nil

		@Option(name: [.customLong("gateway")], help: ArgumentHelp("IP gateway\n", discussion: "gateway used for --vmnet=(host|shared), e.g., \"192.168.105.1\" (default: decided by macOS)"))
		var gateway: String? = nil

		@Option(name: [.customLong("dhcp-end")], help: "end of the DHCP range")
		var dhcpEnd: String? = nil

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
				if self.networkName == nil {
					throw ValidationError("interface is required for bridged mode")
				}

				if self.gateway != nil {
					throw ValidationError("gateway is not allowed for bridged mode")
				}

				if self.dhcpEnd != nil {
					throw ValidationError("dhcp-end is not allowed for bridged mode")
				}
			} else if self.gateway != nil {
				if self.dhcpEnd == nil {
					throw ValidationError("dhcp-end is required for host/shared mode when gateway is specified")
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
					socketURL = try NetworksHandler.vmnetEndpoint(mode: self.mode, networkName: self.networkName, asSystem: self.asSystem)
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

	static func isPhysicalInterface(name: String) -> Bool {
		let interfaces = VZBridgedNetworkInterface.networkInterfaces

		for interface in interfaces {
			if interface.identifier == name {
				return true
			}
		}

		return false
	}

	static func vmnetEndpoint(mode: VMNetMode, networkName: String? = nil, asSystem: Bool) throws -> (URL, URL) {
		let createIfNotExists: Bool = asSystem ? geteuid() == 0 : true
		let home = try Home.init(asSystem: asSystem, createItIfNotExists: createIfNotExists)
		let dirName: String

		if mode == .bridged {
			dirName = networkName!
		} else if mode == .host {
			dirName = "host"
		} else {
			dirName = networkName ?? "shared"
		}

		let networkDirectory = home.networkDirectory.appendingPathComponent(dirName, isDirectory: true)

		if try networkDirectory.exists() == false && createIfNotExists {
			try FileManager.default.createDirectory(at: networkDirectory, withIntermediateDirectories: true)
		}

		return (networkDirectory.appendingPathComponent("vmnet.sock").absoluteURL, networkDirectory.appendingPathComponent("vmnet.pid").absoluteURL)
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
		var environment = ProcessInfo.processInfo.environment

		if environment["CAKE_HOME"] == nil {
			environment["CAKE_HOME"] = try Home(asSystem: runAsSystem).cakeHomeDirectory.path
		}

		process.executableURL = sudoURL
		process.environment = environment
		process.arguments = ["--non-interactive", binary.path, "--help"]
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

		arguments.append("--log-level=\(Logger.LoggingLevel().rawValue)")
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
			if let networkName = networkConfig.networkName {
				arguments.append("--interface=\(networkName)")
			} else {
				throw ServiceError("interface is required for bridged mode")
			}
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
		var environment = ProcessInfo.processInfo.environment

		if environment["CAKE_HOME"] == nil {
			environment["CAKE_HOME"] = try Home(asSystem: runAsSystem).cakeHomeDirectory.path
		}

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
			runningArguments = ["--non-interactive", "--", executableURL.absoluteURL.path]
			process.executableURL = sudoURL
			process.standardInput = FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: false)
		}

		arguments.append("--pidfile=\(pidFile.absoluteURL.path)")
		arguments.append("--fd=\(fd)")

		runningArguments.append(contentsOf: arguments)
		Logger(self).info("Running: \(process.executableURL!.path) \(runningArguments.joined(separator: " "))")

		try? pidFile.delete()

		process.arguments = runningArguments
		process.environment = environment
		process.standardOutput = FileHandle.standardOutput
		process.standardError = FileHandle.standardError
		process.terminationHandler = { process in
			Logger(self).info("Process died: \(process.terminationStatus), \(process.terminationReason)")
			kill(getpid(), SIGUSR2)
		}

		try process.run()
		try pidFile.waitPID(maxRetries: 1200)

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
			socketURL = try NetworksHandler.vmnetEndpoint(mode: .bridged, networkName: networkConfig.networkName, asSystem: runAsSystem)
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
				if let networkName = networkConfig.networkName {
					arguments.append("--vmnet-interface=\(networkName)")
				} else {
					throw ServiceError("interface is required for bridged mode")
				}
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

			arguments.append(contentsOf: ["networks", "run", "--log-level=\(Logger.LoggingLevel().rawValue)", "--mode=\(mode.stringValue)"])

			if runAsSystem {
				arguments.append("--system")
			}

			if let interfaceID = networkConfig.uuid {
				arguments.append("--interface-id=\(interfaceID)")
			}

			if mode == .bridged {
				if let networkName = networkConfig.networkName {
					arguments.append("--interface=\(networkName)")
				} else {
					throw ServiceError("interface is required for bridged mode")
				}
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

			runningArguments = ["--non-interactive", executableURL.absoluteURL.path]
		}

		runningArguments.append(contentsOf: arguments)

		Logger(self).info("Running: \(process.executableURL!.path) \(runningArguments.joined(separator: " "))")

		var environment = ProcessInfo.processInfo.environment

		if environment["CAKE_HOME"] == nil {
			environment["CAKE_HOME"] = try Home(asSystem: runAsSystem).cakeHomeDirectory.path
		}

		process.arguments = runningArguments
		process.environment = environment
		process.standardInput = FileHandle.nullDevice
		process.standardOutput = debug ? FileHandle.standardOutput : FileHandle.nullDevice
		process.standardError = debug ? FileHandle.standardError : FileHandle.nullDevice
		process.terminationHandler = { process in
			Logger(self).info("Process terminated: \(process.terminationStatus), \(process.terminationReason)")
			kill(getpid(), SIGUSR2)
		}

		try process.run()
		try socketURL.1.waitPID()
	}

	static func configure(network: UsedNetworkConfig, asSystem: Bool, fromService: Bool = false) throws {
		let home: Home = try Home(asSystem: runAsSystem)
		var networkConfig = try home.sharedNetworks()

		guard let networkName = network.networkName else {
			throw ServiceError("Network name is required")
		}

		guard let exisiting = networkConfig.sharedNetworks[networkName] else {
			throw ServiceError("Network \(networkName) doesn't exists")
		}

		networkConfig.sharedNetworks[networkName] = VZSharedNetwork(
			netmask: network.netmask ?? exisiting.netmask,
			dhcpStart: network.dhcpStart ?? exisiting.dhcpStart,
			dhcpEnd: network.dhcpEnd ?? exisiting.dhcpEnd,
			uuid: network.uuid ?? exisiting.uuid,
			nat66Prefix: network.nat66Prefix ?? exisiting.nat66Prefix
		)

		try home.setSharedNetworks(networkConfig)
	}

	static func run(networkName: String, asSystem: Bool) throws -> (URL, URL) {
		let home: Home = try Home(asSystem: runAsSystem)
		let sharedNetworks = try home.sharedNetworks().sharedNetworks
		let socketURL: (URL, URL)
		let mode: VMNetMode
		let networkConfig: UsedNetworkConfig

		if Self.isPhysicalInterface(name: networkName) {
			socketURL = try Self.vmnetEndpoint(mode: .bridged, networkName: networkName, asSystem: asSystem)
			mode = .bridged
			networkConfig = .init(name: networkName)
		} else {
			guard let network = sharedNetworks[networkName] else {
				throw ServiceError("Network \(networkName) doesn't exists")
			}

			mode = networkName == "host" ? .host : .shared
			socketURL = try Self.vmnetEndpoint(mode: mode, networkName: networkName, asSystem: asSystem)
			networkConfig = UsedNetworkConfig(name: networkName, config: network)
		}

		try Self.run(mode: mode, networkConfig: networkConfig, socketPath: socketURL.0, pidFile: socketURL.1)

		return socketURL
	}

	static func create(networkName: String, network: VZSharedNetwork, asSystem: Bool, fromService: Bool = false) throws {
		let home: Home = try Home(asSystem: runAsSystem)
		var networkConfig = try home.sharedNetworks()

		if networkConfig.sharedNetworks[networkName] != nil {
			throw ServiceError("Network \(networkName) already exists")
		}

		networkConfig.sharedNetworks[networkName] = network

		try home.setSharedNetworks(networkConfig)
	}

	static func delete(networkName: String, asSystem: Bool, fromService: Bool = false) throws {
		let home: Home = try Home(asSystem: runAsSystem)
		var networkConfig = try home.sharedNetworks()

		if networkConfig.sharedNetworks[networkName] == nil {
			throw ServiceError("Network \(networkName) doesn't exists")
		}

		networkConfig.sharedNetworks.removeValue(forKey: networkName)

		try home.setSharedNetworks(networkConfig)
	}

	static func start(options: NetworksHandler.VMNetOptions) throws {
		let vzvmnet = try options.createVZVMNet()

		try vzvmnet.1.start()
	}

	static func stop(networkName: String, asSystem: Bool, fromService: Bool = false) throws -> String {
		let socketURL = try Self.vmnetEndpoint(mode: .shared, networkName: networkName, asSystem: asSystem)
		let pidURL = socketURL.1

		_ = pidURL.killPID(SIGTERM)

		return "stopped interface"
	}

	static func stop(mode: VMNetMode, networkName: String? = nil, asSystem: Bool, fromService: Bool = false) throws -> String {
		let socketURL = try Self.vmnetEndpoint(mode: mode, networkName: networkName, asSystem: asSystem)
		let pidURL = socketURL.1

		_ = pidURL.killPID(SIGTERM)

		return "stopped interface"
	}

	static func networks(asSystem: Bool) throws -> [BridgedNetwork] {
		var networks: [BridgedNetwork] = [BridgedNetwork(name: "nat", description: "NAT shared network", interfaceID: "nat", endpoint: "")]
		let home: Home = try Home(asSystem: runAsSystem)
		let networkConfig = try home.sharedNetworks()
		
		let createBridgedNetwork: (_ mode: VMNetMode, _ name: String, _ description: String, _ uuid: String, _ gateway: String, _ dhcpEnd: String) throws -> BridgedNetwork = { (mode, name, description, uuid, gateway, dhcpEnd) in
			let socketURL = try NetworksHandler.vmnetEndpoint(mode: mode, networkName: name, asSystem: asSystem)
			let endpoint: String

			if try socketURL.0.exists() {
				endpoint = socketURL.0.absoluteURL.path
			} else {
				endpoint = "not running"
			}

			return BridgedNetwork(name: name, description: description, gateway: gateway, dhcpEnd: dhcpEnd, interfaceID: uuid, endpoint: endpoint)
		}

		try networks.append(contentsOf: VZBridgedNetworkInterface.networkInterfaces.map { inf in
			return try createBridgedNetwork(.bridged, inf.identifier, inf.localizedDisplayName ?? inf.identifier, "", "", "")
		})

		return try networkConfig.sharedNetworks.reduce(into: networks) {
			let cidr = $1.value.netmask.netmaskToCidr()
			let gateway = "\($1.value.dhcpStart)/\(cidr)"
			let dhcpEnd = "\($1.value.dhcpEnd)/\(cidr)"
			let uuid = $1.value.uuid ?? ""


			$0.append(try createBridgedNetwork(.shared, $1.key, "Shared network", uuid, gateway, dhcpEnd))
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
				try Self.create(networkName: self.request.name, network: self.request.create.toVZSharedNetwork(), asSystem: asSystem, fromService: true)
				message = "Network \(self.request.name) created"
			case .remove:
				try Self.delete(networkName: self.request.name, asSystem: asSystem, fromService: true)
				message = "Network \(self.request.name) deleted"
			case .start:
				_ = try Self.run(networkName: self.request.name, asSystem: asSystem)
				message = "Network \(self.request.name) started"
			case .shutdown:
				_ = try Self.stop(networkName: self.request.name, asSystem: asSystem, fromService: true)
				return "Network \(self.request.name) stopped"
			case .configure:
				try Self.configure(network: self.request.configure.toUsedNetworkConfig(), asSystem: asSystem)
				message = "Network \(self.request.name) configured"
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
