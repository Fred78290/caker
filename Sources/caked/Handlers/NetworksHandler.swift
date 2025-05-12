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
import UniformTypeIdentifiers

let SUDO = "sudo"

extension Caked_CreateNetworkRequest {
	func toVZSharedNetwork() -> VZSharedNetwork {
		return VZSharedNetwork(
			mode: self.mode == .shared ? .shared : .host,
			netmask: self.netmask,
			dhcpStart: self.gateway,
			dhcpEnd: self.dhcpEnd,
			dhcpLease: self.hasDhcpLease ? self.dhcpLease : nil,
			interfaceID: self.hasUuid ? self.uuid : UUID().uuidString,
			nat66Prefix: self.hasNat66Prefix ? self.nat66Prefix : nil
		)
	}
}

extension Caked_ConfigureNetworkRequest {
	func toUsedNetworkConfig() -> UsedNetworkConfig {
		return UsedNetworkConfig(
			mode: .shared,
			networkName: self.name,
			netmask: self.hasNetmask ? self.netmask : nil,
			dhcpStart: self.hasGateway ? self.gateway : nil,
			dhcpEnd: self.hasDhcpEnd ? self.dhcpEnd : nil,
			dhcpLease: self.hasDhcpLease ? self.dhcpLease : nil,
			interfaceID: self.hasUuid ? self.uuid : nil,
			nat66Prefix: self.hasNat66Prefix ? self.nat66Prefix : nil
		)
	}
}

enum VMNetMode: String, CaseIterable, ExpressibleByArgument, Codable {
	var defaultValueDescription: String { "host" }

	static let allValueStrings: [String] = VMNetMode.allCases.map { "\($0)" }

	case host
	case shared
	case bridged

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

	var integerValue: uint64 {
		switch self {
		case .host:
			return 1000
		case .shared:
			return 1001
		case .bridged:
			return 1002
		}
	}
}

struct UsedNetworkConfig {
	var mode: VMNetMode
	var networkName: String
	var netmask: String? = nil
	var dhcpStart: String? = nil
	var dhcpEnd: String? = nil
	var dhcpLease: Int32? = nil
	var interfaceID: String? = UUID().uuidString
	var nat66Prefix: String? = nil

	init(mode: VMNetMode, networkName: String, netmask: String?, dhcpStart: String?, dhcpEnd: String?, dhcpLease: Int32?, interfaceID: String? = nil, nat66Prefix: String? = nil) {
		self.mode = mode
		self.networkName = networkName
		self.netmask = netmask
		self.dhcpStart = dhcpStart
		self.dhcpEnd = dhcpEnd
		self.dhcpLease = dhcpLease
		self.interfaceID = interfaceID
		self.nat66Prefix = nat66Prefix
	}

	init(name: String, config: VZSharedNetwork? = nil) {
		self.mode = config?.mode ?? .bridged
		self.networkName = name
		self.netmask = config?.netmask
		self.dhcpStart = config?.dhcpStart
		self.dhcpEnd = config?.dhcpEnd
		self.dhcpLease = config?.dhcpLease
		self.interfaceID = config?.interfaceID
		self.nat66Prefix = config?.nat66Prefix
	}
}

final class SudoCaked {
	let process: Process
	var stdout: Data?
	var stderr: Data?

	convenience init(arguments: [String], asSystem: Bool, log: FileHandle) throws {
		try self.init(arguments: arguments, asSystem: asSystem, standardOutput: log, standardError: log)
	}

	init(arguments: [String], asSystem: Bool, standardOutput: FileHandle? = nil, standardError: FileHandle? = nil) throws {
		let (sudoable, sudoURL, executableURL) = try Self.checkIfSudoable()

		guard sudoable else {
			throw ServiceError("\(executableURL.lastPathComponent) is not sudoable")
		}

		let process = Process()
		var runningArguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--user=root", "--group=#\(getegid())", "--", executableURL.path]

		if asSystem {
			runningArguments.append("--system")
		}

		runningArguments.append(contentsOf: arguments)

		process.executableURL = sudoURL
		process.arguments = runningArguments
		process.environment = try Root.environment(asSystem: asSystem)
		process.standardInput = FileHandle.nullDevice

		if let standardOutput = standardOutput {
			process.standardOutput = standardOutput
			self.stdout = nil
		} else {
			let outputPipe = Pipe()
			var stdout = Data()

			self.stdout = stdout
			outputPipe.fileHandleForReading.readabilityHandler = { handler in
				stdout.append(handler.availableData)
			}

			process.standardOutput = outputPipe

		}

		if let standardError = standardError {
			process.standardError = standardError
			self.stderr = nil
		} else {
			let errorPipe = Pipe()
			var stderr = Data()

			self.stderr = stderr

			errorPipe.fileHandleForReading.readabilityHandler = { handler in
				stderr.append(handler.availableData)
			}

			process.standardError = errorPipe
		}

		self.process = process
	}

	func run() throws -> Self{
		try self.process.run()

		return self
	}

	func waitUntilExit() -> Int32 {
		self.process.waitUntilExit()

		return self.process.terminationStatus
	}

	func runAndWait() throws -> Int32 {
		try self.run().waitUntilExit()
	}

	var standardOutput: String {
		guard let stdout = self.stdout else {
			return ""
		}

		if let output = String(data: stdout, encoding: .utf8) {
			return output
		} else {
			return ""
		}
	}

	var standardError: String {
		guard let stderr = self.stderr else {
			return ""
		}

		if  let error = String(data: stderr, encoding: .utf8) {
			return error
		} else {
			return ""
		}
	}

	var terminationStatus: Int32 {
		if self.process.isRunning {
			return 0
		}

		let status = self.process.terminationStatus

		if status != 0 {
			if let stdout = self.stdout {
				try? FileHandle.standardOutput.write(contentsOf: stdout)
			}

			if let stderr = self.stderr {
				try? FileHandle.standardError.write(contentsOf: stderr)
			}
		}

		return status
	}

	var terminationReason: Process.TerminationReason {
		self.process.terminationReason
	}

	static func checkIfSudoable() throws -> (Bool, URL, URL) {
		guard let binary = URL.binary("caked") else {
			throw ServiceError("caked not found in path")
		}

		guard let sudoURL = URL.binary(SUDO) else {
			throw ServiceError("sudo not found in path")
		}

		return (try checkIfSudoable(sudoURL: sudoURL, binary: binary), sudoURL, binary)
	}

	static func checkIfSudoable(sudoURL: URL, binary: URL) throws -> Bool {
		if geteuid() == 0 {
			return true
		}

		let info = try FileManager.default.attributesOfItem(atPath: binary.path) as NSDictionary

		if info.fileOwnerAccountID() == 0 && (info.filePosixPermissions() & Int(S_ISUID)) != 0 {
			return true
		}

		let process = Process()

		process.executableURL = sudoURL
		process.environment = try Root.environment(asSystem: false)
		process.arguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--user=root", "--group=#\(getegid())", "--", binary.path, "--help"]
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
}

struct NetworksHandler: CakedCommandAsync {
	var request: Caked_NetworkRequest

	struct VMNetOptions: ParsableArguments {
		@Flag(help: .private)
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

		@Option(name: [.customLong("mac-address")], help: ArgumentHelp("Mac Address of network interface\n", discussion: "Mac address configured for VM network interface, autogenerated if not specified", valueName: "mac"))
		var macAddress: String = VZMACAddress.randomLocallyAdministered().string

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

			self.debug = false
			self.networkName = networkName
			self.socketGroup = "staff"
			self.socketPath = nil
			self.vmfd = nil
			self.pidFile = nil

			if NetworksHandler.isPhysicalInterface(name: networkName) {
				self.mode = .bridged
				self.macAddress = VZMACAddress.randomLocallyAdministered().string
				self.gateway = nil
				self.dhcpEnd = nil
				self.dhcpLease = nil
				self.subnetMask = "255.255.255.0"
				self.interfaceID = UUID().uuidString
				self.nat66Prefix = nil
			} else {
				let home: Home = try Home(asSystem: asSystem)
				let networkConfig = try home.sharedNetworks()

				guard let network = networkConfig.sharedNetworks[networkName] else {
					throw ServiceError("Network \(networkName) doesn't exists")
				}

				self.mode = network.mode
				self.gateway = network.dhcpStart
				self.dhcpEnd = network.dhcpEnd
				self.dhcpLease = network.dhcpLease
				self.subnetMask = network.netmask
				self.interfaceID = network.interfaceID
				self.nat66Prefix = network.nat66Prefix
			}
		}

		func validate() throws {
			if self.vmfd != nil && self.socketPath != nil {
				throw ValidationError("fd and socket-path are mutually exclusive \(self.vmfd!) \(self.socketPath!)")
			}

			if let vmfd = self.vmfd {
				if self.pidFile == nil {
					throw ValidationError("pidfile is required when using fd")
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

		func vmnetEndpoint(asSystem: Bool) throws -> (URL, URL) {
			if let socketPath = self.socketPath, let pidFile = self.pidFile {
				return (URL(fileURLWithPath: socketPath), URL(fileURLWithPath: pidFile))
			} else {
				return try NetworksHandler.vmnetEndpoint(networkName: self.networkName, asSystem: asSystem)
			}
		}

		func createVZVMNet(asSystem: Bool) throws -> (URL, VZVMNet) {
			let network: VZSharedNetwork

			if NetworksHandler.isPhysicalInterface(name: self.networkName) {
				network = VZSharedNetwork(mode: self.mode, netmask: "", dhcpStart: "", dhcpEnd: "", dhcpLease: nil, interfaceID: self.interfaceID, nat66Prefix: nil)
			} else {
				network = VZSharedNetwork(mode: self.mode, netmask: self.subnetMask, dhcpStart: self.gateway!, dhcpEnd: self.dhcpEnd!, dhcpLease: self.dhcpLease, interfaceID: self.interfaceID, nat66Prefix: self.nat66Prefix)
			}

			guard let vmfd = self.vmfd else {
				let socketURL = try vmnetEndpoint(asSystem: asSystem)

				guard let grp = getgrnam(self.socketGroup) else {
					throw ServiceError("Failed to get group \(self.socketGroup)")
				}

				if let dhcpLease = self.dhcpLease {
					_ = try NetworksHandler.setDHCPLease(leaseTime: dhcpLease, asSystem: asSystem)
				}

				if try socketURL.0.exists() == false {
					let vzvmnet = VZVMNetSocket(
						on: Root.group.next(),
						socketPath: socketURL.0,
						socketGroup: grp.pointee.gr_gid,
						networkName: self.networkName,
						networkConfig: network,
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
			                                networkName: self.networkName,
			                                networkConfig: network,
			                                pidFile: pidUrl)

			return (pidUrl, vzvmnet)
		}
	}

	static func setDHCPLease(leaseTime: Int32, asSystem: Bool) throws -> String {
		if geteuid() == 0 {
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
		} else if try SudoCaked(arguments: ["networks", "set-dhcp-lease", "\(leaseTime)"], asSystem: asSystem).runAndWait() != 0 {
			throw ServiceError("Failed to set DHCP lease time")
		}

		return "DHCP lease time set to \(leaseTime) seconds"
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

	static func findPhysicalInterface(name: String) -> VZBridgedNetworkInterface? {
		for interface in VZBridgedNetworkInterface.networkInterfaces {
			if interface.identifier == name {
				return interface
			}
		}

		return nil
	}

	static func vmnetEndpoint(networkName: String, asSystem: Bool) throws -> (URL, URL) {
		let createIfNotExists: Bool = asSystem ? geteuid() == 0 : true
		let home = try Home.init(asSystem: asSystem, createItIfNotExists: createIfNotExists)
		let networkDirectory = home.networkDirectory.appendingPathComponent(networkName, isDirectory: true)

		if try networkDirectory.exists() == false && createIfNotExists {
			try FileManager.default.createDirectory(at: networkDirectory, withIntermediateDirectories: true)
		}

		return (networkDirectory.socketPath(name: "vmnet"), networkDirectory.appendingPathComponent("vmnet.pid").absoluteURL)
	}

	// Must be run as root
	static func restartNetworkService(networkName: String, asSystem: Bool) throws -> String {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, asSystem: asSystem)
		let pidURL = socketURL.1

		guard pidURL.isPIDRunning() else {
			Logger(self).info("Network \(networkName) is not running")
			return "Network \(networkName) is not running"
		}

		if geteuid() == 0 {
			Logger(self).info("Restart network \(networkName)")

			if pidURL.killPID(SIGUSR2) < 0 {
				throw ServiceError("Failed to kill process \(pidURL.path): \(String(cString: strerror(errno)))")
			} else {
				Logger(self).info("Network \(networkName) restarted")
			}
		} else if try SudoCaked(arguments: ["networks", "restart", networkName], asSystem: asSystem).runAndWait() != 0 {
			throw ServiceError("Failed to restart network \(networkName)")
		}

		return "Network \(networkName) restarted"
	}

	static func startNetworkService(networkName: String, asSystem: Bool) throws {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, asSystem: asSystem)

		if socketURL.1.isPIDRunning() {
			Logger(self).info("Network \(networkName) is already running")
			return
		}

		_ = try Self.start(networkName: networkName, asSystem: asSystem)
	}

	static func run(fileDescriptor: Int32, networkConfig: UsedNetworkConfig, pidFile: URL, asSystem: Bool) throws -> ProcessWithSharedFileHandle {
		Logger(self).info("Start VMNet mode: \(networkConfig.mode.rawValue) Using vmfd: \(fileDescriptor)")

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

		arguments.append("--mode=\(networkConfig.mode.rawValue)")

		if Logger.Level() >= .debug {
			arguments.append("--debug")
		}

		if let interfaceID = networkConfig.interfaceID {
			arguments.append("--interface-id=\(interfaceID)")
		}

		if networkConfig.mode == .bridged {
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
			guard let sudoURL = URL.binary(SUDO) else {
				throw ServiceError("sudo not found in path")
			}

			guard try SudoCaked.checkIfSudoable(sudoURL: sudoURL, binary: executableURL) else {
				throw ServiceError("\(executableURL.lastPathComponent) is not sudoable")
			}

			fd = STDIN_FILENO
			// We need to use the file descriptor of stdin, otherwise the process will not be able to read from it and will block forever
			runningArguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--user=root", "--group=#\(getegid())", "--", executableURL.path]
			process.executableURL = sudoURL
			process.standardInput = FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: false)

			if asSystem {
				runningArguments.append("--system")
			}
		}

		arguments.append("--fd=\(fd)")
		arguments.append("--pidfile=\(pidFile.path)")

		runningArguments.append(contentsOf: arguments)
		Logger(self).info("Running: \(process.executableURL!.path) \(runningArguments.joined(separator: " "))")

		try? pidFile.delete()

		process.arguments = runningArguments
		process.environment = try Root.environment(asSystem: asSystem)
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

	static func run(useLimaVMNet: Bool = false, mode: VMNetMode, networkConfig: UsedNetworkConfig, socketPath: URL? = nil, pidFile: URL? = nil, asSystem: Bool) throws {
		let socketURL: (URL, URL)
		let executableURL: URL
		let debug = Logger.Level() >= .debug
		var arguments: [String] = []

		if let socketPath = socketPath, let pidFile = pidFile {
			socketURL = (socketPath.absoluteURL, pidFile.absoluteURL)
		} else {
			socketURL = try NetworksHandler.vmnetEndpoint(networkName: networkConfig.networkName, asSystem: asSystem)
		}

		Logger(self).info("Start VMNet mode: \(mode.rawValue) Using socket: \(socketURL.0.path)")

		if useLimaVMNet {

			guard let socket_vmnet = URL.binary("socket_vmnet") else {
				throw ServiceError("socket_vmnet not found in path")
			}

			executableURL = socket_vmnet

			//if Logger.Level() >= .debug {
			//	arguments.append("--debug")
			//}

			//arguments.append("--vmnet-vz")
			arguments.append("--vmnet-mode=\(mode.rawValue)")

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
				if let interfaceID = networkConfig.interfaceID {
					arguments.append("--vmnet-interface-id=\(interfaceID)")
				}
				if let nat66Prefix = networkConfig.nat66Prefix {
					arguments.append("--vmnet-nat66-prefix=\(nat66Prefix)")
				}
			}

			arguments.append("--pidfile=\(socketURL.1.path)")
			arguments.append(socketURL.0.path)
		} else if let caker = URL.binary("caked") {
			executableURL = caker

			arguments.append(contentsOf: ["networks", "run", "--mode=\(mode.rawValue)"])

			if Logger.LoggingLevel() > .info {
				arguments.append("--log-level=\(Logger.LoggingLevel().rawValue)")
			}

			if asSystem {
				arguments.append("--system")
			}

			if let interfaceID = networkConfig.interfaceID {
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

			arguments.append("--pidfile=\(socketURL.1.path)")
			arguments.append(socketURL.0.path)
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
			guard let sudoURL = URL.binary(SUDO) else {
				throw ServiceError("sudo not found in path")
			}

			guard try SudoCaked.checkIfSudoable(sudoURL: sudoURL, binary: executableURL) else {
				throw ServiceError("\(executableURL.lastPathComponent) is not sudoable")
			}

			process.executableURL = sudoURL

			runningArguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--user=root", "--group=#\(getegid())", "--", executableURL.path]

			if asSystem {
				runningArguments.append("--system")
			}
		}

		runningArguments.append(contentsOf: arguments)

		Logger(self).info("Running: \(process.executableURL!.path) \(runningArguments.joined(separator: " "))")

		process.arguments = runningArguments
		process.environment = try Root.environment(asSystem: asSystem)
		process.standardInput = FileHandle.nullDevice
		process.terminationHandler = { process in
			Logger(self).info("Process terminated: \(process.terminationStatus), \(process.terminationReason)")
			kill(getpid(), SIGUSR2)
		}

		if debug {
			process.standardOutput = FileHandle.standardOutput
			process.standardError = FileHandle.standardError
		} else {
			let logURL = socketURL.0.deletingPathExtension().appendingPathExtension("log")

			if try logURL.exists() == false {
				FileManager.default.createFile(atPath: logURL.path, contents: nil)
			}

			let output: FileHandle = try FileHandle(forWritingTo: logURL)

			process.standardOutput = output
			process.standardError = output
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
		let home: Home = try Home(asSystem: asSystem)
		var networkConfig = try home.sharedNetworks()

		guard let existing = networkConfig.sharedNetworks[networkName] else {
			throw ServiceError("Network \(networkName) doesn't exists")
		}

		if existing == network {
			return "Network \(networkName) unchanged"
		}

		networkConfig.sharedNetworks[networkName] = network

		try home.setSharedNetworks(networkConfig)

		return try self.restartNetworkService(networkName: networkName, asSystem: asSystem)
	}

	static func configure(network: UsedNetworkConfig, asSystem: Bool) throws -> String {
		let home: Home = try Home(asSystem: asSystem)
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
			mode: exisiting.mode,
			netmask: network.netmask ?? exisiting.netmask,
			dhcpStart: network.dhcpStart ?? exisiting.dhcpStart,
			dhcpEnd: network.dhcpEnd ?? exisiting.dhcpEnd,
			dhcpLease: network.dhcpLease ?? exisiting.dhcpLease,
			interfaceID: network.interfaceID ?? exisiting.interfaceID,
			nat66Prefix: network.nat66Prefix ?? exisiting.nat66Prefix
		)

		if changed != exisiting {
			try changed.validate()
			networkConfig.sharedNetworks[network.networkName] = changed
			try home.setSharedNetworks(networkConfig)

			return try self.restartNetworkService(networkName: network.networkName, asSystem: asSystem)
		} else {
			return "Network \(network.networkName) unchanged"
		}
	}

	static func start(networkName: String, asSystem: Bool) throws -> (URL, URL) {
		let home: Home = try Home(asSystem: asSystem)
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

		if asSystem {
			arguments.append("--system")
		}

		try? socketURL.0.delete()

		if geteuid() == 0 {
			process.executableURL = executableURL
			runningArguments = []
		} else {
			guard let sudoURL = URL.binary(SUDO) else {
				throw ServiceError("sudo not found in path")
			}

			guard try SudoCaked.checkIfSudoable(sudoURL: sudoURL, binary: executableURL) else {
				throw ServiceError("\(executableURL.lastPathComponent) is not sudoable")
			}

			process.executableURL = sudoURL

			runningArguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--user=root", "--group=#\(getegid())", "--", executableURL.path]

			if asSystem {
				runningArguments.append("--system")
			}
		}

		runningArguments.append(contentsOf: arguments)

		Logger(self).info("Running: \(process.executableURL!.path) \(runningArguments.joined(separator: " "))")

		process.arguments = runningArguments
		process.environment = try Root.environment(asSystem: asSystem)
		process.standardInput = FileHandle.nullDevice
		process.terminationHandler = { process in
			if process.terminationReason == .uncaughtSignal {
				Logger(self).info("Network \(networkName) terminated: \(process.terminationStatus), \(process.terminationReason)")
			} else {
				Logger(self).info("Network \(networkName) exited: \(process.terminationStatus)")
			}
		}

		if debug {
			process.standardOutput = FileHandle.standardOutput
			process.standardError = FileHandle.standardError
		} else {
			let logURL = socketURL.0.deletingPathExtension().appendingPathExtension("log")

			if try logURL.exists() == false {
				FileManager.default.createFile(atPath: logURL.path, contents: nil)
			}

			let output = try FileHandle(forWritingTo: logURL)

			process.standardOutput = output
			process.standardError = output
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
		let home: Home = try Home(asSystem: asSystem)
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

		try Self.run(mode: mode, networkConfig: networkConfig, socketPath: socketURL.0, pidFile: socketURL.1, asSystem: asSystem)

		return socketURL
	}

	static func create(networkName: String, network: VZSharedNetwork, asSystem: Bool) throws -> String {
		let home: Home = try Home(asSystem: asSystem)
		var networkConfig = try home.sharedNetworks()

		if networkConfig.sharedNetworks[networkName] != nil {
			throw ServiceError("Network \(networkName) already exists")
		}

		networkConfig.sharedNetworks[networkName] = network

		try home.setSharedNetworks(networkConfig)

		return "Network \(networkName) created"
	}

	static func delete(networkName: String, asSystem: Bool) throws -> String {
		let home: Home = try Home(asSystem: asSystem)
		var networkConfig = try home.sharedNetworks()

		if networkConfig.sharedNetworks[networkName] == nil {
			throw ServiceError("Network \(networkName) doesn't exists")
		}

		let socketURL = try NetworksHandler.vmnetEndpoint(networkName: networkName, asSystem: asSystem)

		if socketURL.1.isPIDRunning() {
			throw ServiceError("Network \(networkName) is running")
		}

		networkConfig.sharedNetworks.removeValue(forKey: networkName)

		try home.setSharedNetworks(networkConfig)

		return "Network \(networkName) deleted"
	}

	static func vmnetFileLog(networkName: String, asSystem: Bool) throws -> FileHandle {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, asSystem: asSystem)
		let logURL = socketURL.0.deletingPathExtension().appendingPathExtension("log")

		if try logURL.exists() == false {
			FileManager.default.createFile(atPath: logURL.path, contents: nil)
		}

		return try FileHandle(forWritingTo: logURL)
	}

	static func start(options: NetworksHandler.VMNetOptions, asSystem: Bool) throws -> String {
		let socketURL = try options.vmnetEndpoint(asSystem: asSystem)

		if socketURL.1.isPIDRunning() {
			throw ServiceError("Network already running")
		}

		if geteuid() == 0 {
			let vzvmnet = try options.createVZVMNet(asSystem: asSystem)
			var signalReconfigure: DispatchSourceSignal? = nil

			if NetworksHandler.isPhysicalInterface(name: options.networkName) == false {
				let sig = DispatchSource.makeSignalSource(signal: SIGUSR2)

				if let dhcpLease = options.dhcpLease {
					_ = try NetworksHandler.setDHCPLease(leaseTime: dhcpLease, asSystem: asSystem)
				}

				Logger(self).info("Allow reconfigure network: \(options.networkName)")

				signal(SIGUSR2, SIG_IGN)

				sig.setEventHandler {
					Logger(self).info("Will reconfigure network: \(options.networkName)")

					do {
						let home: Home = try Home(asSystem: asSystem)
						let networkConfig = try home.sharedNetworks()

						if let network = networkConfig.sharedNetworks[options.networkName] {
							try? vzvmnet.1.reconfigure(networkConfig: network)
						}
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

			return "Network \(options.networkName) terminated"
		} else if try SudoCaked(arguments: ["networks", "start", options.networkName], asSystem: asSystem, log: try Self.vmnetFileLog(networkName: options.networkName, asSystem: asSystem)).run().terminationStatus != 0 {
			throw ServiceError("Failed to start networks \(options.networkName)")
		} else {
			let socketURL = try options.vmnetEndpoint(asSystem: asSystem)

			try socketURL.1.waitPID()

			return "Network \(options.networkName) started"
		}
	}

	static func stop(pidURL: URL, asSystem: Bool) throws -> String {
		guard try pidURL.exists() else {
			throw ServiceError("PID file \(pidURL.path) doesn't exists")
		}

		guard pidURL.isPIDRunning() else {
			Logger(self).info("PID \(pidURL.path) is not running")
			return "PID \(pidURL.path) is not running"
		}

		if geteuid() == 0 {
			// We are running as root, so we can just kill the process
			if pidURL.killPID(SIGTERM) < 0 {
				throw ServiceError("Failed to kill process \(pidURL.path): \(String(cString: strerror(errno)))")
			} else {
				Logger(self).info("PID \(pidURL.path) stopped")
			}
		} else if try SudoCaked(arguments: ["networks", "stop", "--pidfile=\(pidURL.path)"], asSystem: asSystem).runAndWait() != 0 {
			throw ServiceError("Failed to kill process \(pidURL.path)")
		} else {
			try pidURL.waitStopped()
		}

		return "PID \(pidURL.path) stopped"
	}

	static func stop(networkName: String, asSystem: Bool) throws -> String {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, asSystem: asSystem)

		if geteuid() == 0 {
			let pidURL = socketURL.1

			guard pidURL.isPIDRunning() else {
				Logger(self).info("Network \(networkName) is not running")
				return "Network \(networkName) is not running"
			}

			// We are running as root, so we can just kill the process
			if pidURL.killPID(SIGTERM) < 0 {
				throw ServiceError("Failed to kill process \(pidURL.path): \(String(cString: strerror(errno)))")
			} else {
				Logger(self).info("Network \(networkName) stopped")
			}
		} else if try SudoCaked(arguments: ["networks", "stop", networkName], asSystem: asSystem).runAndWait() != 0 {
			throw ServiceError("Failed to kill network process \(networkName)")
		} else {
			// Wait for the process to exit
			try socketURL.1.waitStopped()
		}

		return "Network \(networkName) stopped"
	}

	static func networks(asSystem: Bool) throws -> [BridgedNetwork] {
		var networks: [BridgedNetwork] = [BridgedNetwork(name: "nat", mode: "nat", description: "NAT shared network", gateway: "", dhcpEnd: "", interfaceID: "nat", endpoint: "")]
		let home: Home = try Home(asSystem: asSystem)
		let networkConfig = try home.sharedNetworks()

		let createBridgedNetwork: (_ name: String, _ description: String, _ mode: String, _ uuid: String, _ gateway: String, _ dhcpEnd: String) throws -> BridgedNetwork = { (name, mode, description, uuid, gateway, dhcpEnd) in
			let socketURL = try NetworksHandler.vmnetEndpoint(networkName: name, asSystem: asSystem)
			let endpoint: String

			if try socketURL.0.exists() {
				endpoint = socketURL.0.path
			} else {
				endpoint = "not running"
			}

			return BridgedNetwork(name: name, mode: mode, description: description, gateway: gateway, dhcpEnd: dhcpEnd, interfaceID: uuid, endpoint: endpoint)
		}

		try networks.append(contentsOf: VZBridgedNetworkInterface.networkInterfaces.map { inf in
			return try createBridgedNetwork(inf.identifier, "bridged", inf.localizedDisplayName ?? inf.identifier, "", "", "")
		})

		return try networkConfig.sharedNetworks.reduce(into: networks) {
			let cidr = $1.value.netmask.netmaskToCidr()
			let gateway = "\($1.value.dhcpStart)/\(cidr)"
			let dhcpEnd = "\($1.value.dhcpEnd)/\(cidr)"
			let uuid = $1.value.interfaceID


			$0.append(try createBridgedNetwork($1.key, $1.value.mode.rawValue, $1.value.mode == .host ? "Hosted network" : "Shared network", uuid, gateway, dhcpEnd))
		}
	}

	static func status(networkName: String, asSystem: Bool) throws -> BridgedNetwork {
		if let inf = NetworksHandler.findPhysicalInterface(name: networkName) {
			return BridgedNetwork(name: networkName, mode: "bridged", description: inf.localizedDisplayName ?? inf.identifier, gateway: "", dhcpEnd: "", interfaceID: inf.identifier, endpoint: "")
		} else {
			let home: Home = try Home(asSystem: asSystem)
			let networkConfig = try home.sharedNetworks()
			let socketURL = try Self.vmnetEndpoint(networkName: networkName, asSystem: asSystem)

			guard let network = networkConfig.sharedNetworks[networkName] else {
				throw ServiceError("Network \(networkName) doesn't exists")
			}

			let mode = network.mode.rawValue
			let description = network.mode == .host ? "Hosted network" : "Shared network"
			let uuid = network.interfaceID
			let gateway = network.dhcpStart
			let dhcpEnd = network.dhcpEnd
			let endpoint: String

			if try socketURL.0.exists() {
				endpoint = socketURL.0.path
			} else {
				endpoint = "not running"
			}

			return BridgedNetwork(name: networkName, mode: mode, description: description, gateway: gateway, dhcpEnd: dhcpEnd, interfaceID: uuid, endpoint: endpoint)
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<Caked_Reply> {
		on.submit {
			let message: String

			switch self.request.command {
			case .infos:
				let result = try Self.networks(asSystem: asSystem)

				return Caked_Reply.with {
					$0.networks = Caked_NetworksReply.with {
						$0.list = Caked_ListNetworksReply.with {
							$0.networks = result.map {
								$0.toCaked_NetworkInfo()
							}
						}
					}
				}
			case .status:
				let result = try Self.status(networkName: self.request.name, asSystem: asSystem)

				return Caked_Reply.with {
					$0.networks = Caked_NetworksReply.with {
						$0.status = result.toCaked_NetworkInfo()
					}
				}
			case .new:
				message = try Self.create(networkName: self.request.create.name, network: self.request.create.toVZSharedNetwork(), asSystem: asSystem)
			case .remove:
				message = try Self.delete(networkName: self.request.name, asSystem: asSystem)
			case .start:
				_ = try Self.start(networkName: self.request.name, asSystem: asSystem)
				message = "Network \(self.request.name) started"
			case .shutdown:
				message = try Self.stop(networkName: self.request.name, asSystem: asSystem)
			case .set:
				message = try Self.configure(network: self.request.configure.toUsedNetworkConfig(), asSystem: asSystem)
			default:
				throw ServiceError("Unknown command")
			}

			return Caked_Reply.with {
				$0.networks = Caked_NetworksReply.with {
					$0.message = message
				}
			}
		}
	}
}
