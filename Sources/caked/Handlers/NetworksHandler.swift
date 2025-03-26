import ArgumentParser
import Foundation
import GRPCLib
import Virtualization
import NIOCore
import TextTable
import NIOPosix
import Logging
import vmnet

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

struct BridgedNetwork: Codable {
	var name: String
	var description: String = ""
	var interfaceID: String = ""
	var endpoint: String = ""
}

struct NetworksHandler: CakedCommand {
	var format: Format

	struct VMNetOptions: ParsableArguments {
		@Flag(name: [.customLong("system"), .customShort("s")], help: "Run caked as system agent, need sudo")
		var asSystem: Bool = false

		@Argument(help: "socket path")
		var socketPath: String? = nil

		@Option(name: [.customLong("fd")], help: "Use file descriptor for VMNet")
		var vmfd: Int? = nil

		@Option(name: [.customLong("socket-group")], help: "socket group name")
		var socketGroup: String = "staff"

		@Option(name: [.customLong("mode")], help: "vmnet mode")
		var mode = VMNetMode.bridged

		@Option(name: [.customLong("interface")], help: ArgumentHelp("interface\n", discussion: "interface used for --vmnet=bridged, e.g., \"en0\""))
		var networkInterface: String? = nil

		@Option(name: [.customLong("gateway")], help: ArgumentHelp("IP gateway\n", discussion: "gateway used for --vmnet=(host|shared), e.g., \"192.168.105.1\" (default: decided by macOS)"))
		var gateway: String? = nil

		@Option(name: [.customLong("dhcp-end")], help: "end of the DHCP range")
		var dhcpEnd: String? = nil

		@Option(name: [.customLong("netmask")], help: ArgumentHelp("subnet mask\n", discussion: "requires --vmnet-gateway to be specified"))
		var subnetMask = "255.255.255.0"

		@Option(name: [.customLong("interface-id")], help: ArgumentHelp("vmnet interface ID\n", discussion: "randomly generated if not specified"))
		var interfaceID = UUID().uuidString

		@Option(name: [.customLong("nat66-prefix")], help: "The IPv6 prefix to use with shared mode")
		var nat66Prefix: String? = nil

		@Option(name: [.customLong("pidfile")], help: "save pid to PIDFILE")
		var pidFile: String? = nil

		func validate() throws {
			runAsSystem = self.asSystem

			if self.vmfd != nil && self.socketPath != nil {
				throw ValidationError("fd and socket-path are mutually exclusive")
			}

			if self.vmfd != nil && self.pidFile == nil {
				throw ValidationError("pidfile is required when using fd")
			}

			if self.mode == .bridged {
				if self.networkInterface == nil {
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
					socketURL = try NetworksHandler.vmnetEndpoint(mode: self.mode, networkInterface: self.networkInterface, asSystem: self.asSystem)
				}

				if try socketURL.0.exists() == false {
					let vzvmnet = VZVMNetSocket(
						on: Root.group.next(),
						socketPath: socketURL.0,
						socketGroup: grp.pointee.gr_gid,
						mode: self.mode,
						networkInterface: self.networkInterface,
						gateway: self.gateway,
						dhcpEnd: self.dhcpEnd,
						subnetMask: self.subnetMask,
						interfaceID: self.interfaceID,
						nat66Prefix: self.nat66Prefix
					)

					return (socketURL.1, vzvmnet)
				} else {
					throw ServiceError("Socket file already exists at \(socketURL.0.path)")
				}
			}

			guard let pidFile = self.pidFile else {
				throw ServiceError("pidfile is required when using vmfd")
			}

			let vzvmnet = VZVMNetFileHandle(on: Root.group.next(),
			                                inputOutput: CInt(vmfd),
			                                mode: self.mode,
			                                networkInterface: self.networkInterface,
			                                gateway: self.gateway,
			                                dhcpEnd: self.dhcpEnd,
			                                subnetMask: self.subnetMask,
			                                interfaceID: self.interfaceID,
			                                nat66Prefix: self.nat66Prefix)

			return (URL(fileURLWithPath: pidFile), vzvmnet)
		}
	}

	static func vmnetEndpoint(mode: VMNetMode, networkInterface: String? = nil, asSystem: Bool) throws -> (URL, URL) {
		let createIfNotExists: Bool = asSystem ? geteuid() == 0 : true
		let home = try Home.init(asSystem: asSystem, createItIfNotExists: createIfNotExists)
		let dirName: String

		if mode == .bridged {
			dirName = networkInterface!
		} else if mode == .host {
			dirName = "host"
		} else {
			dirName = "shared"
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

		process.executableURL = sudoURL
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

	static func run(vmFD: Int32,
	                mode: VMNetMode,
	                networkInterface: String? = nil,
	                gateway: String? = nil,
	                dhcpEnd: String? = nil,
	                subnetMask: String? = "255.255.255.0",
	                interfaceID: String = UUID().uuidString,
	                nat66Prefix: String? = nil,
					pidFile: URL) throws -> Process {

		guard let executableURL = URL.binary("caked") else {
			throw ServiceError("caked not found in path")
		}

		guard let sudoURL = URL.binary("sudo") else {
			throw ServiceError("sudo not found in path")
		}

		var arguments: [String] = [ "networks", "start", "--log-level", "\(Logger.LoggingLevel().rawValue)"]

		Logger(self).info("Start VMNet mode: \(mode.stringValue) Using vmfd: \(vmFD)")

		arguments.append(contentsOf: ["--mode", "\(mode.stringValue)"])

		if let networkInterface = networkInterface {
			arguments.append(contentsOf: ["--interface", networkInterface])
		}

		if let gateway = gateway {
			arguments.append(contentsOf: ["--gateway", gateway])

			if let dhcpEnd = dhcpEnd {
				arguments.append(contentsOf: ["--dhcp-end", dhcpEnd])
			}

			if let subnetMask = subnetMask {
				arguments.append(contentsOf: ["--netmask", subnetMask])
			}

			if let nat66Prefix = nat66Prefix {
				arguments.append(contentsOf: ["--nat66-prefix", nat66Prefix])
			}
		}

		arguments.append(contentsOf: ["--pidfile", pidFile.path])
		arguments.append(contentsOf: ["--fd", "\(STDIN_FILENO)"])

		guard try checkIfSudoable(binary: executableURL) else {
			throw ServiceError("\(executableURL.lastPathComponent) is not sudoable")
		}

		let process = Process()

		var runningArguments: [String] = ["--non-interactive", executableURL.path]

		runningArguments.append(contentsOf: arguments)

		Logger(self).info("Running: \(sudoURL.path) \(runningArguments.joined(separator: " "))")

		process.executableURL = sudoURL
		process.arguments = runningArguments
		process.standardInput = FileHandle(fileDescriptor: vmFD, closeOnDealloc: true)
		process.standardOutput = FileHandle.standardOutput
		process.standardError = FileHandle.standardError
		process.terminationHandler = { process in
			Logger(self).info("Process terminated: \(process.terminationStatus), \(process.terminationReason)")
			kill(getpid(), SIGUSR2)
		}

		try process.run()
		
		return process
	}

	static func run(standalone: Bool = false,
	                mode: VMNetMode,
	                networkInterface: String? = nil,
	                gateway: String? = nil,
	                dhcpEnd: String? = nil,
	                subnetMask: String? = "255.255.255.0",
	                interfaceID: String = UUID().uuidString,
	                nat66Prefix: String? = nil,
	                socketPath: URL? = nil,
	                pidFile: URL? = nil) throws {
		let socketURL: (URL, URL)
		let executableURL: URL
		var arguments: [String] = []

		if let socketPath = socketPath, let pidFile = pidFile {
			socketURL = (socketPath, pidFile)
		} else {
			socketURL = try NetworksHandler.vmnetEndpoint(mode: .bridged, networkInterface: networkInterface, asSystem: runAsSystem)
		}

		guard let sudoURL = URL.binary("sudo") else {
			throw ServiceError("sudo not found in path")
		}

		Logger(self).info("Start VMNet mode: \(mode.stringValue) Using socket: \(socketURL.0.path)")

		if standalone, let socket_vmnet = URL.binary("socket_vmnet") {	
			executableURL = socket_vmnet
			arguments.append(contentsOf: ["--vmnet-mode", "\(mode.stringValue)"])

			if let networkInterface = networkInterface {
				arguments.append(contentsOf: ["--vmnet-interface", networkInterface])
			}

			if let gateway = gateway {
				arguments.append(contentsOf: ["--vmnet-gateway", gateway])

				if let dhcpEnd = dhcpEnd {
					arguments.append(contentsOf: ["--vmnet-dhcp-end", dhcpEnd])
				}

				if let subnetMask = subnetMask {
					arguments.append(contentsOf: ["--vmnet-mask", subnetMask])
				}

				if let nat66Prefix = nat66Prefix {
					arguments.append(contentsOf: ["--vmnet-nat66-prefix", nat66Prefix])
				}
			}

			arguments.append(contentsOf: ["--pidfile", socketURL.1.path])
			arguments.append(socketURL.0.path)

		} else if let caker = URL.binary("caked") {
			executableURL = caker

			arguments.append(contentsOf: ["networks", "start"])

			if runAsSystem {
				arguments.append(contentsOf: ["--system"])
			}

			arguments.append(contentsOf: ["--log-level", "\(Logger.LoggingLevel().rawValue)"])

			arguments.append(contentsOf: ["--mode", "\(mode.stringValue)"])

			if let networkInterface = networkInterface {
				arguments.append(contentsOf: ["--interface", networkInterface])
			}

			if let gateway = gateway {
				arguments.append(contentsOf: ["--gateway", gateway])

				if let dhcpEnd = dhcpEnd {
					arguments.append(contentsOf: ["--dhcp-end", dhcpEnd])
				}

				if let subnetMask = subnetMask {
					arguments.append(contentsOf: ["--netmask", subnetMask])
				}

				if let nat66Prefix = nat66Prefix {
					arguments.append(contentsOf: ["--nat66-prefix", nat66Prefix])
				}
			}

			arguments.append(contentsOf: ["--pidfile", socketURL.1.path])
			arguments.append(socketURL.0.path)
		} else {
			throw ServiceError("caked not found in path")
		}

		if socketURL.1.isPIDRunning() {
			throw ServiceError("\(executableURL.path) is already running")
		}

		try? socketURL.0.delete()

		guard try checkIfSudoable(binary: executableURL) else {
			throw ServiceError("\(executableURL.lastPathComponent) is not sudoable")
		}

		let process = Process()
		var runningArguments: [String] = ["--non-interactive", executableURL.path]

		runningArguments.append(contentsOf: arguments)

		Logger(self).info("Running: \(sudoURL.path) \(runningArguments.joined(separator: " "))")

		process.executableURL = sudoURL
		process.arguments = runningArguments
		process.standardInput = FileHandle.nullDevice
		process.standardOutput = FileHandle.standardOutput
		process.standardError = FileHandle.standardError
		process.terminationHandler = { process in
			Logger(self).info("Process terminated: \(process.terminationStatus), \(process.terminationReason)")
			kill(getpid(), SIGUSR2)
		}

		try process.run()

		let maxRetries = 10
		var retries = 0

		while retries < maxRetries {
			if FileManager.default.fileExists(atPath: socketURL.0.path) {
				Logger(self).info("Socket file exists at \(socketURL.0.path)")
				return
			}

			Thread.sleep(forTimeInterval: 1)

			retries += 1
		}

		throw ServiceError("Socket file did not appear within the expected time")
	}

	static func start(options: NetworksHandler.VMNetOptions) throws {
		let vzvmnet = try options.createVZVMNet()

		try vzvmnet.0.writePID()

		defer {
			try? vzvmnet.0.delete()
		}

		try vzvmnet.1.start()
	}

	static func stop(mode: VMNetMode, networkInterface: String? = nil, asSystem: Bool) throws -> String {
		let socketURL = try Self.vmnetEndpoint(mode: mode, networkInterface: networkInterface, asSystem: asSystem)
		let pidURL = socketURL.1

		if try pidURL.exists() {
			let pid = try String(contentsOf: pidURL, encoding: .ascii)

			if let pidInt = Int32(pid) {
				kill(pidInt, SIGTERM)
			}
		}

		return "stopped interface"
	}

	static func networks() -> [BridgedNetwork] {
		var networks: [BridgedNetwork] = [BridgedNetwork(name: "nat", description: "NAT shared network", interfaceID: "nat", endpoint: "")]

		networks.append(contentsOf: VZBridgedNetworkInterface.networkInterfaces.map { inf in
			BridgedNetwork(name: inf.identifier, description: inf.localizedDisplayName ?? inf.identifier, interfaceID: inf.identifier, endpoint: "")
		})

		return networks
	}

	func run(on: EventLoop, asSystem: Bool) throws -> String {
		self.format.renderList(style: Style.grid, uppercased: true, Self.networks())
	}
}
