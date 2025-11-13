import ArgumentParser
import Foundation
import GRPCLib
import Logging
import NIOCore
import NIOPosix
import SystemConfiguration
import TextTable
import UniformTypeIdentifiers
import Virtualization
import vmnet

extension Caked_CreateNetworkRequest {
	public func toVZSharedNetwork() -> VZSharedNetwork {
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
	public func toUsedNetworkConfig() -> UsedNetworkConfig {
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

public enum VMNetMode: String, CaseIterable, ExpressibleByArgument, Codable {
	public var defaultValueDescription: String { "host" }

	public static let allValueStrings: [String] = VMNetMode.allCases.map { "\($0)" }

	case nat
	case host
	case shared
	case bridged

	public var description: String {
		switch self {
			case .host:
				return "Hosted network"
			case .shared:
				return "Shared network"
			case .bridged:
				return "Bridged network"
			case .nat:
				return "NAT shared network"
		}
	}
	
	public init?(argument: String) {
		switch argument {
		case "nat":
			self = .nat
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

	public var integerValue: uint64 {
		switch self {
		case .nat:
			return 1001
		case .host:
			return 1000
		case .shared:
			return 1001
		case .bridged:
			return 1002
		}
	}
}

extension BridgedNetworkMode {
	init(from: VMNetMode) {
		self.init(rawValue: from.rawValue)!
	}
}

public struct UsedNetworkConfig {
	public var mode: VMNetMode
	public var networkName: String
	public var netmask: String? = nil
	public var dhcpStart: String? = nil
	public var dhcpEnd: String? = nil
	public var dhcpLease: Int32? = nil
	public var interfaceID: String? = UUID().uuidString
	public var nat66Prefix: String? = nil

	public init(mode: VMNetMode, networkName: String, netmask: String?, dhcpStart: String?, dhcpEnd: String?, dhcpLease: Int32?, interfaceID: String? = nil, nat66Prefix: String? = nil) {
		self.mode = mode
		self.networkName = networkName
		self.netmask = netmask
		self.dhcpStart = dhcpStart
		self.dhcpEnd = dhcpEnd
		self.dhcpLease = dhcpLease
		self.interfaceID = interfaceID
		self.nat66Prefix = nat66Prefix
	}

	public init(name: String, config: VZSharedNetwork? = nil) {
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

public struct NetworksHandler {
	private static let InternetSharingPrefs = "/Library/Preferences/SystemConfiguration/com.apple.InternetSharing.default.plist" as CFString
	private static let BootpD = "bootpd" as CFString
	private static let DHCPLeaseTimeSecs = "DHCPLeaseTimeSecs"

	public static func getDHCPLease() throws -> Int32 {
		guard let ref = SCPreferencesCreate(nil, Home.cakedCommandName as CFString, InternetSharingPrefs) else {
			throw ServiceError("Unable to create SCPreferences")
		}

		guard let props = SCPreferencesGetValue(ref, BootpD) as? NSDictionary else {
			throw ServiceError("Unable to load SCPreferences")
		}

		guard let lease = props["DHCPLeaseTimeSecs"] as? Int32 else {
			throw ServiceError("Unable to load SCPreferences")
		}

		return lease
	}

	public static func setDHCPLease(leaseTime: Int32, runMode: Utils.RunMode) throws -> String {
		if geteuid() == 0 {
			guard let ref = SCPreferencesCreate(nil, Home.cakedCommandName as CFString, InternetSharingPrefs) else {
				throw ServiceError("Unable to create SCPreferences")
			}

			Logger(self).debug("Set DHCP lease time to \(leaseTime) seconds")

			let lease = [
					DHCPLeaseTimeSecs: leaseTime as CFNumber
				] as CFDictionary

			SCPreferencesSetValue(ref, BootpD, lease)
			SCPreferencesCommitChanges(ref)
			SCPreferencesApplyChanges(ref)
		} else if try SudoCaked(arguments: ["networks", "set-dhcp-lease", "\(leaseTime)"], runMode: runMode).runAndWait() != 0 {
			throw ServiceError("Failed to set DHCP lease time")
		}

		return "DHCP lease time set to \(leaseTime) seconds"
	}

	public static func isPhysicalInterface(name: String) -> Bool {
		return VZBridgedNetworkInterface.networkInterfaces.first(where: { $0.identifier == name }) != nil
	}

	public static func findPhysicalInterface(name: String) -> VZBridgedNetworkInterface? {
		return VZBridgedNetworkInterface.networkInterfaces.first(where: { $0.identifier == name })
	}

	public static func vmnetEndpoint(networkName: String, runMode: Utils.RunMode) throws -> (URL, URL) {
		let createIfNotExists: Bool = runMode.isSystem ? geteuid() == 0 : true
		let home = try Home.init(runMode: runMode, createItIfNotExists: createIfNotExists)
		let networkDirectory = home.networkDirectory.appendingPathComponent(networkName, isDirectory: true)

		if try networkDirectory.exists() == false && createIfNotExists {
			try FileManager.default.createDirectory(at: networkDirectory, withIntermediateDirectories: true)
		}

		return (networkDirectory.socketPath(name: "vmnet"), networkDirectory.appendingPathComponent("vmnet.pid").absoluteURL)
	}

	// Must be run as root
	public static func restartNetworkService(networkName: String, runMode: Utils.RunMode) throws -> String {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)
		let pidURL = socketURL.1

		guard pidURL.isCakedRunning() else {
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
		} else if try SudoCaked(arguments: ["networks", "restart", networkName], runMode: runMode).runAndWait() != 0 {
			throw ServiceError("Failed to restart network \(networkName)")
		}

		return "Network \(networkName) restarted"
	}

	public static func startNetworkService(networkName: String, runMode: Utils.RunMode) throws {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)

		if socketURL.1.isCakedRunning() {
			Logger(self).info("Network \(networkName) is already running")
			return
		}

		_ = try Self.startNetwork(networkName: networkName, runMode: runMode)
	}

	public static func run(fileDescriptor: Int32, networkConfig: UsedNetworkConfig, pidFile: URL, runMode: Utils.RunMode) throws -> ProcessWithSharedFileHandle {
		Logger(self).info("Start VMNet mode: \(networkConfig.mode.rawValue) Using vmfd: \(fileDescriptor)")

		guard let executableURL = URL.binary(phUseLimaVMNet ? "sock-vmnet" : Home.cakedCommandName) else {
			throw ServiceError("caked not found in path")
		}

		var arguments: [String] = []
		var runningArguments: [String]
		let process = ProcessWithSharedFileHandle()

		if phUseLimaVMNet == false {
			arguments.append(contentsOf: ["networks", "run"])
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

			if runMode.isSystem {
				runningArguments.append("--system")
			}
		}

		arguments.append("--fd=\(fd)")
		arguments.append("--pidfile=\(pidFile.path)")

		runningArguments.append(contentsOf: arguments)
		Logger(self).debug("Running: \(process.executableURL!.path) \(runningArguments.joined(separator: " "))")

		try? pidFile.delete()

		process.arguments = runningArguments
		process.environment = try Utilities.environment(runMode: runMode)
		process.standardOutput = FileHandle.standardOutput
		process.standardError = FileHandle.standardError
		process.terminationHandler = { process in
			Logger(self).debug("Process died: \(process.terminationStatus), \(process.terminationReason)")
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

	public static func run(useLimaVMNet: Bool = false, mode: VMNetMode, networkConfig: UsedNetworkConfig, socketPath: URL? = nil, pidFile: URL? = nil, runMode: Utils.RunMode) throws {
		let socketURL: (URL, URL)
		let executableURL: URL
		let debug = Logger.Level() >= .debug
		var arguments: [String] = []

		if let socketPath = socketPath, let pidFile = pidFile {
			socketURL = (socketPath.absoluteURL, pidFile.absoluteURL)
		} else {
			socketURL = try NetworksHandler.vmnetEndpoint(networkName: networkConfig.networkName, runMode: runMode)
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
		} else if let caker = URL.binary(Home.cakedCommandName) {
			executableURL = caker

			arguments.append(contentsOf: ["networks", "run", "--mode=\(mode.rawValue)"])

			if Logger.LoggingLevel() > .info {
				arguments.append("--log-level=\(Logger.LoggingLevel().rawValue)")
			}

			if runMode.isSystem {
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

		if socketURL.1.isCakedRunning() {
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

			if runMode.isSystem {
				runningArguments.append("--system")
			}
		}

		runningArguments.append(contentsOf: arguments)

		Logger(self).debug("Running: \(process.executableURL!.path) \(runningArguments.joined(separator: " "))")

		process.arguments = runningArguments
		process.environment = try Utilities.environment(runMode: runMode)
		process.standardInput = FileHandle.nullDevice
		process.terminationHandler = { process in
			Logger(self).debug("Process terminated: \(process.terminationStatus), \(process.terminationReason)")
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

	public static func configure(networkName: String, network: VZSharedNetwork, runMode: Utils.RunMode) -> ConfiguredNetworkReply {
		do {
			let home: Home = try Home(runMode: runMode)
			var networkConfig = try home.sharedNetworks()
			
			guard let existing = networkConfig.sharedNetworks[networkName] else {
				throw ServiceError("Network \(networkName) doesn't exists")
			}
			
			if existing == network {
				return ConfiguredNetworkReply(name: networkName, configured: false, reason: "Network \(networkName) unchanged")
			}
			
			networkConfig.userNetworks[networkName] = network
						
			do {
				return ConfiguredNetworkReply(name: networkName, configured: true, reason: try self.restartNetworkService(networkName: networkName, runMode: runMode))
			} catch {
				return ConfiguredNetworkReply(name: networkName, configured: true, reason: "\(error)")
			}
		} catch {
			return ConfiguredNetworkReply(name: networkName, configured: false, reason: "\(error)")
		}
	}

	public static func configure(network: UsedNetworkConfig, runMode: Utils.RunMode) -> ConfiguredNetworkReply {
		do {
			let home: Home = try Home(runMode: runMode)
			var networkConfig = try home.sharedNetworks()
			
			guard network.networkName != "" else {
				return ConfiguredNetworkReply(name: "", configured: false, reason: "Network name is required")
			}
			
			guard Self.isPhysicalInterface(name: String(network.networkName)) == false else {
				return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: "Network \(network.networkName) is a physical interface")
			}
			
			guard let exisiting = networkConfig.sharedNetworks[network.networkName] else {
				return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: "Network \(network.networkName) doesn't exists")
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
				try changed.validate(runMode: runMode)
				networkConfig.userNetworks[network.networkName] = changed
				try home.setSharedNetworks(networkConfig)
				
				do {
					return ConfiguredNetworkReply(name: network.networkName, configured: true, reason: try self.restartNetworkService(networkName: network.networkName, runMode: runMode))
				} catch {
					return ConfiguredNetworkReply(name: network.networkName, configured: true, reason: "\(error)")
				}
			} else {
				return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: "Network \(network.networkName) unchanged")
			}
		} catch {
			return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: "\(error)")
		}
	}

	public static func start(networkName: String, runMode: Utils.RunMode) -> StartedNetworkReply {
		do {
			_ = try startNetwork(networkName: networkName, runMode: runMode)
			
			return StartedNetworkReply(name: networkName, started: true, reason: "Network \(networkName) started")
		} catch {
			return StartedNetworkReply(name: networkName, started: false, reason: "\(error)")
		}
	}

	public static func startNetwork(networkName: String, runMode: Utils.RunMode) throws -> (URL, URL) {
		let home: Home = try Home(runMode: runMode)
		let sharedNetworks = try home.sharedNetworks().sharedNetworks
		let socketURL: (URL, URL)

		if Self.isPhysicalInterface(name: networkName) {
			socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)
		} else {
			guard let sharedNetwork = sharedNetworks[networkName] else {
				throw ServiceError("Network \(networkName) doesn't exists")
			}

			try sharedNetwork.validate(runMode: runMode)

			socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)
		}

		if socketURL.1.isCakedRunning() {
			throw ServiceError("Network \(networkName) already running \(socketURL.1.path)")
		}

		Logger(self).info("Start network: \(networkName) using socket: \(socketURL.0.path)")

		guard let executableURL = URL.binary(Home.cakedCommandName) else {
			throw ServiceError("caked not found in path")
		}

		var arguments = ["networks", "start", networkName]
		let process = Process()
		var runningArguments: [String]
		let debug = Logger.Level() >= .debug

		if Logger.LoggingLevel() > .info {
			arguments.append("--log-level=\(Logger.LoggingLevel().rawValue)")
		}

		if runMode.isSystem {
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

			if runMode.isSystem {
				runningArguments.append("--system")
			}
		}

		runningArguments.append(contentsOf: arguments)

		Logger(self).debug("Running: \(process.executableURL!.path) \(runningArguments.joined(separator: " "))")

		process.arguments = runningArguments
		process.environment = try Utilities.environment(runMode: runMode)
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

	public static func run(networkName: String, runMode: Utils.RunMode) throws -> (URL, URL) {
		let home: Home = try Home(runMode: runMode)
		let sharedNetworks = try home.sharedNetworks().sharedNetworks
		let socketURL: (URL, URL)
		let mode: VMNetMode
		let networkConfig: UsedNetworkConfig

		if Self.isPhysicalInterface(name: networkName) {
			socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)
			mode = .bridged
			networkConfig = .init(name: networkName)
		} else {
			guard let network = sharedNetworks[networkName] else {
				throw ServiceError("Network \(networkName) doesn't exists")
			}

			mode = networkName == "host" ? .host : .shared
			socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)
			networkConfig = UsedNetworkConfig(name: networkName, config: network)
		}

		try Self.run(mode: mode, networkConfig: networkConfig, socketPath: socketURL.0, pidFile: socketURL.1, runMode: runMode)

		return socketURL
	}

	public static func create(networkName: String, network: VZSharedNetwork, runMode: Utils.RunMode) -> CreatedNetworkReply {
		do {
			let home: Home = try Home(runMode: runMode)
			var networkConfig = try home.sharedNetworks()

			if networkConfig.sharedNetworks[networkName] != nil {
				return CreatedNetworkReply(name: networkName, created: false, reason: "Network \(networkName) already exists")
			}

			networkConfig.userNetworks[networkName] = network

			try home.setSharedNetworks(networkConfig)

			return CreatedNetworkReply(name: networkName, created: true, reason: "Network \(networkName) created")
		} catch {
			return CreatedNetworkReply(name: networkName, created: false, reason: "\(error)")
		}
	}

	public static func delete(networkName: String, runMode: Utils.RunMode) -> DeleteNetworkReply {
		do {
			let home: Home = try Home(runMode: runMode)
			var networkConfig = try home.sharedNetworks()
			
			guard networkConfig.sharedNetworks[networkName] != nil else {
				return DeleteNetworkReply(name: networkName, deleted: false, reason: "Network \(networkName) doesn't exists")
			}
			
			let socketURL = try NetworksHandler.vmnetEndpoint(networkName: networkName, runMode: runMode)
			
			if socketURL.1.isCakedRunning() {
				return DeleteNetworkReply(name: networkName, deleted: false, reason: "Network \(networkName) is running")
			}
			
			networkConfig.userNetworks.removeValue(forKey: networkName)
			
			try home.setSharedNetworks(networkConfig)
			
			return DeleteNetworkReply(name: networkName, deleted: true, reason: "Network \(networkName) deleted")
		} catch {
			return DeleteNetworkReply(name: networkName, deleted: false, reason: "\(error)")
		}
	}

	public static func vmnetFileLog(networkName: String, runMode: Utils.RunMode) throws -> FileHandle {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)
		let logURL = socketURL.0.deletingPathExtension().appendingPathExtension("log")

		if try logURL.exists() == false {
			FileManager.default.createFile(atPath: logURL.path, contents: nil)
		}

		return try FileHandle(forWritingTo: logURL)
	}

	public static func stop(pidURL: URL, runMode: Utils.RunMode) -> String {
		do {
			guard try pidURL.exists() else {
				throw ServiceError("PID file \(pidURL.path) doesn't exists")
			}
			
			guard pidURL.isCakedRunning() else {
				Logger(self).debug("PID \(pidURL.path) is not running")
				return "PID \(pidURL.path) is not running"
			}
			
			if geteuid() == 0 {
				// We are running as root, so we can just kill the process
				if pidURL.killPID(SIGTERM) < 0 {
					throw ServiceError("Failed to kill process \(pidURL.path): \(String(cString: strerror(errno)))")
				} else {
					Logger(self).debug("PID \(pidURL.path) stopped")
				}
			} else if try SudoCaked(arguments: ["networks", "stop", "--pidfile=\(pidURL.path)"], runMode: runMode).runAndWait() != 0 {
				throw ServiceError("Failed to kill process \(pidURL.path)")
			} else {
				try pidURL.waitStopped()
			}
			
			return "PID \(pidURL.path) stopped"
		} catch {
			return "\(error)"
		}
	}

	public static func stop(networkName: String, runMode: Utils.RunMode) -> StoppedNetworkReply {
		do {
			return StoppedNetworkReply(name: networkName, stopped: true, reason: try stopNetwork(networkName: networkName, runMode: runMode))
		} catch {
			return StoppedNetworkReply(name: networkName, stopped: false, reason: "\(error)")
		}
	}

	public static func stopNetwork(networkName: String, runMode: Utils.RunMode) throws -> String {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)

		if geteuid() == 0 {
			let pidURL = socketURL.1

			guard pidURL.isCakedRunning() else {
				Logger(self).info("Network \(networkName) is not running")
				return "Network \(networkName) is not running"
			}

			// We are running as root, so we can just kill the process
			if pidURL.killPID(SIGTERM) < 0 {
				throw ServiceError("Failed to kill process \(pidURL.path): \(String(cString: strerror(errno)))")
			} else {
				Logger(self).info("Network \(networkName) stopped")
			}
		} else if try SudoCaked(arguments: ["networks", "stop", networkName], runMode: runMode).runAndWait() != 0 {
			throw ServiceError("Failed to kill network process \(networkName)")
		} else {
			// Wait for the process to exit
			try socketURL.1.waitStopped()
		}

		return "Network \(networkName) stopped"
	}

	public static func natNetworkInfos() throws -> String {
		let address = try Shell.bash(to: "defaults", arguments: ["read", "/Library/Preferences/SystemConfiguration/com.apple.vmnet.plist", "Shared_Net_Address"])
		let netmask = try Shell.bash(to: "defaults", arguments: ["read", "/Library/Preferences/SystemConfiguration/com.apple.vmnet.plist", "Shared_Net_Mask"])

		return "\(address)/\(netmask.netmaskToCidr())"
	}
	
	public static func defaultNatNetwork() -> BridgedNetwork {
		var dhcpStart = ""
		var dhcpEnd = ""
		var dhcpLease = ""

		if let lease = try? getDHCPLease() {
			dhcpLease = "\(lease)"
		}

		do {
			if geteuid() == 0 {
				dhcpStart = try natNetworkInfos()
			} else {
				let sudo = try SudoCaked(arguments: ["networks", "nat-infos", "--text"], runMode: .user)

				if try sudo.runAndWait() == 0 {
					dhcpStart = sudo.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
				}
			}

			if dhcpStart.isEmpty == false {
				if let network = dhcpStart.toNetwork() {
					dhcpEnd = "\(network.range.upperBound.description)/\(network.bits)"
				}
			}
		} catch {
			Logger("NetworksHandler").error("Unable to get nat infos: \(error)")
		}

		return BridgedNetwork(name: "nat", mode: .nat, description: "NAT shared network", gateway: dhcpStart, dhcpEnd: dhcpEnd, dhcpLease: dhcpLease, interfaceID: "nat", endpoint: "")
	}

	public static func networks(runMode: Utils.RunMode) -> ListNetworksReply {
		do {
			var networks: [BridgedNetwork] = []
			let home: Home = try Home(runMode: runMode)
			let networkConfig = try home.sharedNetworks()
			
			let createBridgedNetwork: (_ name: String, _ mode: BridgedNetworkMode, _ description: String, _ uuid: String, _ gateway: String, _ dhcpEnd: String, _ dhcpLease: String) throws -> BridgedNetwork = { (name, mode, description, uuid, gateway, dhcpEnd, dhcpLease) in
				let socketURL = try NetworksHandler.vmnetEndpoint(networkName: name, runMode: runMode)
				let endpoint: String
				
				if try socketURL.0.exists() {
					endpoint = socketURL.0.path
				} else {
					endpoint = ""
				}
				
				return BridgedNetwork(name: name, mode: mode, description: description, gateway: gateway, dhcpEnd: dhcpEnd, dhcpLease: dhcpLease, interfaceID: uuid, endpoint: endpoint)
			}
			
			let networkInterfaces = VZSharedNetwork.networkInterfaces(includeSharedNetworks: false, runMode: runMode)
			
			try networks.append(
				contentsOf: VZBridgedNetworkInterface.networkInterfaces.compactMap { inf in
					if let address = networkInterfaces[inf.identifier] {
						return try createBridgedNetwork(inf.identifier, .bridged, inf.localizedDisplayName ?? inf.identifier, "", address.network.description, "\(address.range.upperBound.description)/\(address.network.bits)", "")
					} else {
						return try createBridgedNetwork(inf.identifier, .bridged, inf.localizedDisplayName ?? inf.identifier, "", "", "", "")
					}
				})
			
			let dhcpLease = networkConfig.defaultNatNetwork.dhcpLease != nil ? "\(networkConfig.defaultNatNetwork.dhcpLease!)" : ""
			
			networks = try networkConfig.sharedNetworks.reduce(into: networks) {
				let cidr = $1.value.netmask.netmaskToCidr()
				let gateway = "\($1.value.dhcpStart)/\(cidr)"
				let dhcpEnd = "\($1.value.dhcpEnd)/\(cidr)"
				let uuid = $1.value.interfaceID
				
				$0.append(try createBridgedNetwork($1.key, .init(from: $1.value.mode), $1.value.mode.description, uuid, gateway, dhcpEnd, dhcpLease))
			}.sorted {
				$0 < $1
			}

			return ListNetworksReply(networks: [], success: false, reason: "Success")
		} catch {
			return ListNetworksReply(networks: [], success: false, reason: "\(error)")
		}
	}
	
	public static func status(networkName: String, runMode: Utils.RunMode) -> NetworkInfoReply {
		do {
			if let inf = NetworksHandler.findPhysicalInterface(name: networkName) {
				let interfaces = VZSharedNetwork.networkInterfaces(includeSharedNetworks: false, runMode: runMode)
				var dhcpEnd: String = ""
				var gateway: String = ""
				
				if let network = interfaces[networkName] {
					gateway = network.network.description
					dhcpEnd = "\(network.range.upperBound.description)/\(network.network.bits)"
				}
				
				return NetworkInfoReply(info: BridgedNetwork(name: networkName, mode: .bridged, description: inf.localizedDisplayName ?? inf.identifier, gateway: gateway, dhcpEnd: dhcpEnd, dhcpLease: "", interfaceID: inf.identifier, endpoint: ""), success: true, reason: "Success")
			} else {
				let home: Home = try Home(runMode: runMode)
				let networkConfig = try home.sharedNetworks()
				let socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)
				
				guard let network = networkConfig.sharedNetworks[networkName] else {
					throw ServiceError("Network \(networkName) doesn't exists")
				}
				
				let mode: BridgedNetworkMode = .init(from: network.mode)
				let uuid = network.interfaceID
				let cidr = network.netmask.netmaskToCidr()
				let gateway = "\(network.dhcpStart)/\(cidr)"
				let dhcpEnd = "\(network.dhcpEnd)/\(cidr)"
				let value = try? Self.getDHCPLease()
				let dhcpLease = value != nil ? "\(value!)" : ""
				let endpoint: String
				
				if try socketURL.0.exists() {
					endpoint = socketURL.0.path
				} else {
					endpoint = ""
				}

				return NetworkInfoReply(info: BridgedNetwork(name: networkName, mode: mode, description: network.mode.description, gateway: gateway, dhcpEnd: dhcpEnd, dhcpLease: dhcpLease, interfaceID: uuid, endpoint: endpoint), success: true, reason: "Success")
			}
		} catch {
			return NetworkInfoReply(info: BridgedNetwork(name: "", mode: .nat, description: "", gateway: "", dhcpLease: "", interfaceID: "", endpoint: ""), success: false, reason: "\(error)")
		}
	}
}
