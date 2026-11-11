import ArgumentParser
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import SystemConfiguration
import TextTable
import UniformTypeIdentifiers
import Virtualization
import vmnet

public typealias ReferencedNetworks = [String: BridgedNetwork.NetworkUsage]

extension ReferencedNetworks {
	public func usage(name: String) -> BridgedNetwork.NetworkUsage {
		if let count = self[name] {
			return count
		}

		return BridgedNetwork.NetworkUsage(used: 0, active: 0)
	}
}

extension Caked_CreateNetworkRequest {
	public func toVZSharedNetwork() -> VZSharedNetwork {
		return VZSharedNetwork(
			mode: self.mode == .shared ? .shared : .host,
			netmask: self.netmask,
			dhcpStart: self.gateway,
			dhcpEnd: self.dhcpEnd,
			dhcpLease: self.hasDhcpLease ? self.dhcpLease : nil,
			interfaceID: self.hasUuid ? self.uuid : UUID().uuidString,
			nat66Prefix: self.hasNat66Prefix ? self.nat66Prefix : nil,
			dns: self.dns
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
			nat66Prefix: self.hasNat66Prefix ? self.nat66Prefix : nil,
			dns: self.hasDns ? self.dns : nil
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
			return String(localized: "Hosted network")
		case .shared:
			return String(localized: "Shared network")
		case .bridged:
			return String(localized: "Bridged network")
		case .nat:
			return BridgeAttachement.defaultNetworkDescription
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
	init(_ from: VMNetMode) {
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
	public var dns: Bool? = false

	public init(mode: VMNetMode, networkName: String, netmask: String?, dhcpStart: String?, dhcpEnd: String?, dhcpLease: Int32?, interfaceID: String? = nil, nat66Prefix: String? = nil, dns: Bool? = nil) {
		self.mode = mode
		self.networkName = networkName
		self.netmask = netmask
		self.dhcpStart = dhcpStart
		self.dhcpEnd = dhcpEnd
		self.dhcpLease = dhcpLease
		self.interfaceID = interfaceID
		self.nat66Prefix = nat66Prefix
		self.dns = dns
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
		self.dns = config?.dns
	}
}

public struct NetworksHandler {
	public static var hasVMNetEntitlement: Bool = Entitlement.hasVMNetworking()
	public static var vmnetNative: Bool {
		// Disable macos26 vmnet features for testing on macOS 26+ when the environment variable is set to "0"
		guard ProcessInfo.processInfo.environment["CAKED_VMNET_NATIVE"] != "0" else {
			return false
		}

		if #available(macOS 26.0, *) {
			return true
		} else {
			return false
		}
	}

	/// Whether the DHCP server (`USE_DHCP_SERVER`) needs the network service to run as root: it reads `/dev/bpf*` and binds port 53.
	/// `CAKED_VMNET_DHCP=vmnet` keeps vmnet's own DHCP, so nothing needs root then. A sandboxed process can't use sudo anyway.
	static var dhcpServerNeedsRoot: Bool {
		#if USE_DHCP_SERVER
			return Bundle.isApplicationSandboxed == false && ProcessInfo.processInfo.environment["CAKED_VMNET_DHCP"] != "vmnet"
		#else
			return false
		#endif
	}

	/// Whether this process can start, signal and stop a network service itself instead of going through `sudo caked`.
	/// vmnet networks created with `vmnet_network_ref` (macOS 26+) or with the vmnet entitlement don't need root, except
	/// when caked serves DHCP: then the service must always be root, whoever starts it.
	public static var canManageNetworkWithoutRoot: Bool {
		canManageNetworkWithoutRoot(mode: nil)
	}

	/// Same as `canManageNetworkWithoutRoot`, for a network of a known `mode` (`nil` when it isn't known).
	/// A bridged network, or any network on a host without `vmnet_network_ref` (macOS 15), never uses caked's DHCP server
	/// (see `usesCakerDHCP(mode:)`), so it keeps starting without root where the vmnet entitlement allows it.
	public static func canManageNetworkWithoutRoot(mode: VMNetMode?) -> Bool {
		if geteuid() == 0 {
			return true
		}

		let servesDHCP = vmnetNative && mode != .bridged && dhcpServerNeedsRoot

		return (vmnetNative || hasVMNetEntitlement) && servesDHCP == false
	}

	/// Whether caked serves DHCP (and, when `dns` is on, DNS on port 53) for this network instead of vmnet. **Full build only**: always false in the App Store build.
	///
	/// Only networks created through `vmnet_network_ref` (macOS 26+) can have vmnet's DHCP switched off, binding the
	/// privileged ports 67/53 needs root, and a sandboxed build can't do either. Everywhere else vmnet keeps serving
	/// DHCP exactly as before. `CAKED_VMNET_DHCP=vmnet` forces that fallback.
	public static func usesCakerDHCP(_ network: VZSharedNetwork) -> Bool {
		usesCakerDHCP(mode: network.mode)
	}

	public static func usesCakerDHCP(mode: VMNetMode) -> Bool {
		// The App Store build is sandboxed (no root, no /dev/bpf): vmnet keeps serving DHCP and DNS there.
		#if !USE_DHCP_SERVER
			return false
		#else
			return Self.usesCakerDHCPOnThisHost(mode: mode)
		#endif
	}

	#if USE_DHCP_SERVER
		private static func usesCakerDHCPOnThisHost(mode: VMNetMode) -> Bool {
			guard mode != .bridged, vmnetNative, Bundle.isApplicationSandboxed == false, geteuid() == 0 else {
				return false
			}

			return ProcessInfo.processInfo.environment["CAKED_VMNET_DHCP"] != "vmnet"
		}
	#endif

	/// `<CAKE_HOME>/net/<name>/dhcpd_leases`: the lease table of the DHCP server of that network.
	public static func dhcpLeaseFile(networkName: String, runMode: Utils.RunMode) throws -> URL {
		try vmnetEndpoint(networkName: networkName, runMode: runMode).pidFile.deletingLastPathComponent().appendingPathComponent(DHCPLeaseStore.leaseFilename, isDirectory: false)
	}

	private static let InternetSharingPrefs = "/Library/Preferences/SystemConfiguration/com.apple.InternetSharing.default.plist" as CFString
	private static let BootpD = "bootpd" as CFString
	private static let DHCPLeaseTimeSecs = "DHCPLeaseTimeSecs"

	public static func getDHCPLease() throws -> Int32 {
		guard let ref = SCPreferencesCreate(nil, Home.cakedCommandName as CFString, InternetSharingPrefs) else {
			throw ServiceError(String(localized: "Unable to create SCPreferences"))
		}

		guard let props = SCPreferencesGetValue(ref, BootpD) as? NSDictionary else {
			throw ServiceError(String(localized: "Unable to load SCPreferences"))
		}

		guard let lease = props["DHCPLeaseTimeSecs"] as? Int32 else {
			throw ServiceError(String(localized: "Unable to load SCPreferences"))
		}

		return lease
	}

	public static func setDHCPLease(leaseTime: Int32, runMode: Utils.RunMode) throws -> String {
		guard Bundle.isApplicationSandboxed == false else {
			throw ServiceError(String(localized: "Unable to set DHCP lease time in sandboxed mode"))
		}

		if geteuid() == 0 {
			guard let ref = SCPreferencesCreate(nil, Home.cakedCommandName as CFString, InternetSharingPrefs) else {
				throw ServiceError(String(localized: "Unable to create SCPreferences"))
			}

			#if DEBUG
				Logger(self).debug("Set DHCP lease time to \(leaseTime) seconds")
			#endif

			let lease =
				[
					DHCPLeaseTimeSecs: leaseTime as CFNumber
				] as CFDictionary

			SCPreferencesSetValue(ref, BootpD, lease)
			SCPreferencesCommitChanges(ref)
			SCPreferencesApplyChanges(ref)
		} else {
			#if USE_AUTHORIZATION_HELPER
				// The privileged helper first; sudo when it is not installed or approved.
				if let reason = try DirectAuthorizationHelperConnector.viaHelperSync(runMode: runMode, { try await $0.setDHCPLease(leaseTime: leaseTime) }) {
					return reason
				}
			#endif

			if try SudoCaked(arguments: ["networks", "set-dhcp-lease", "\(leaseTime)"], runMode: runMode).runAndWait() != 0 {
				throw ServiceError(String(localized: "Failed to set DHCP lease time"))
			}
		}

		return "DHCP lease time set to \(leaseTime) seconds"
	}

	public static func isPhysicalInterface(name: String) -> Bool {
		return VZBridgedNetworkInterface.networkInterfaces.first(where: { $0.identifier == name }) != nil
	}

	public static func findPhysicalInterface(name: String) -> VZBridgedNetworkInterface? {
		return VZBridgedNetworkInterface.networkInterfaces.first(where: { $0.identifier == name })
	}

	public static func vmnetEndpoint(networkName: String, runMode: Utils.RunMode) throws -> (socket: URL, pidFile: URL) {
		let createIfNotExists: Bool = runMode.isSystem ? geteuid() == 0 : true
		let home = try Home.init(runMode: runMode, createItIfNotExists: createIfNotExists)
		let networkDirectory = home.networkDirectory.appendingPathComponent(networkName, isDirectory: true)

		if try networkDirectory.exists() == false && createIfNotExists {
			try FileManager.default.createDirectory(at: networkDirectory, withIntermediateDirectories: true)
		}

		return (networkDirectory.socketPath(name: "net"), networkDirectory.appendingPathComponent("pid").absoluteURL)
	}

	// Must be run as root
	public static func restartNetworkService(networkName: String, runMode: Utils.RunMode) throws -> String {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)
		let pidURL = socketURL.pidFile
		let isPhysicalInterface = Self.isPhysicalInterface(name: networkName)

		if isPhysicalInterface && NetworksHandler.hasVMNetEntitlement {
			return String(localized: "Network \(networkName) is handled natively, please use a different network")
		}

		guard pidURL.isCakedRunning() else {
			Logger(self).info("Network \(networkName) is not running")
			return String(localized: "Network \(networkName) is not running")
		}

		Logger(self).info("Restart network \(networkName)")

		let client = try Self.getVMNetControlClient(pidURL, runMode: runMode)

		defer {
			try? client.channel.close().wait()
		}

		_ = try client.restart(.init()).response.wait()

		return String(localized: "Network \(networkName) restarted")
	}

	public static func startNetworkService(networkName: String, runMode: Utils.RunMode) throws {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)

		if socketURL.pidFile.isCakedRunning() {
			if let pid = socketURL.pidFile.readPID() {
				Logger(self).info("Network \(networkName) is already running with PID=\(pid)")
			} else {
				Logger(self).info("Network \(networkName) is already running with undetermined PID")
			}

			return
		}

		_ = try Self.startNetwork(networkName: networkName, runMode: runMode)
	}

	public static func startNetworkServices(networks: [BridgeAttachement], runMode: Utils.RunMode) throws {
		let home: Home = try Home(runMode: runMode)
		let networkConfig = try home.sharedNetworks()
		let sharedNetworks = networkConfig.sharedNetworks
		var bridgedNetwork: String? = nil
		let logger = Logger(self)
		let networks: [BridgeAttachement] = networks.compactMap { inf in
			if inf.isBridged() {
				bridgedNetwork = CakedKeyConfig.bridgedNetwork.string()

				if bridgedNetwork == nil {
					logger.error("Bridged network is not configured, skipping bridged networks")
					return nil
				}
			}

			return inf
		}

		guard networks.isEmpty == false else {
			logger.warn("No networks to start, skipping")
			return
		}

		try networks.forEach { inf in
			if let networkName = inf.isBridged() ? bridgedNetwork : inf.network {
				let physicalInterface = NetworksHandler.isPhysicalInterface(name: networkName)
				let networkConfig = sharedNetworks[networkName]

				if physicalInterface {
					if CakedLib.NetworksHandler.hasVMNetEntitlement == false {
						try NetworksHandler.startNetworkService(networkName: networkName, runMode: runMode)
					} else {
						logger.warn("Network interface \(networkName) handled by the Virtualization framework via the VMNetworking entitlement")
					}
				} else if networkConfig != nil {
					try NetworksHandler.startNetworkService(networkName: networkName, runMode: runMode)
				} else {
					logger.error("Network interface \(networkName) not found")
				}
			}
		}

		logger.info("Started \(networks.count) network\(networks.count == 1 ? "" : "s")")
	}

	/// A standalone network process started by `run(fileDescriptor:…)`: a child of this process, or a root process owned by the
	/// privileged helper (then only its pid is known, and it is stopped through the network's control client).
	public enum RunningNetworkProcess {
		case process(ProcessWithSharedFileHandle)
		case helper(pid: pid_t)

		public var isRunning: Bool {
			switch self {
			case .process(let process):
				return process.isRunning
			case .helper(let pid):
				// Signal 0 only checks: EPERM means the root process exists.
				return kill(pid, 0) == 0 || errno == EPERM
			}
		}

		public var processIdentifier: pid_t {
			switch self {
			case .process(let process):
				return process.processIdentifier
			case .helper(let pid):
				return pid
			}
		}
	}

	public static func run(fileDescriptor: Int32, networkConfig: UsedNetworkConfig, pidFile: URL, runMode: Utils.RunMode) throws -> RunningNetworkProcess {
		Logger(self).info("Start VMNet mode: \(networkConfig.mode.rawValue) Using vmfd: \(fileDescriptor)")

		guard let executableURL = URL.binary(Home.cakedCommandName) else {
			throw ServiceError(String(localized: "caked not found in path"))
		}

		var arguments: [String] = []
		var runningArguments: [String]
		let process = try Bundle.createProcessWithSharedFileHandle()

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
			guard networkConfig.networkName != String.empty else {
				throw ServiceError(String(localized: "interface is required for bridged mode"))
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

			if networkConfig.dns == true {
				arguments.append("--dns")
			}
		}

		var fd = fileDescriptor
		let logger = Logger(self)

		var environment = try Utilities.environment(runMode: runMode)
		let direct = NetworksHandler.canManageNetworkWithoutRoot(mode: networkConfig.mode)

		#if USE_AUTHORIZATION_HELPER
			// The privileged helper runs it as root on a duplicate of the descriptor, without sudo. Nothing waits on a child
			// process here: a watcher tells this process (SIGUSR2) when the root process is gone, like the termination handler below.
			if direct == false && ProcessInfo.processInfo.environment["CAKED_VMNET_NATIVE"] != "0" {
				let helperArguments = Array(arguments.dropFirst(2))
				let handle = FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: false)
				let helperCanUsePID: Bool = {
					guard let helperHome = try? Home(runMode: runMode) else {
						return false
					}
					let homePath = helperHome.cakeHomeDirectory.resolvingSymlinksInPath().standardizedFileURL.path
					let pidPath = pidFile.resolvingSymlinksInPath().standardizedFileURL.path
					return pidFile.pathExtension == "pid" && pidPath.hasPrefix(homePath + "/")
				}()

				if helperCanUsePID, let pid = try DirectAuthorizationHelperConnector.viaHelperSync(runMode: runMode, { try await $0.runNetwork(arguments: helperArguments, pidFile: pidFile, fileHandle: handle, runMode: runMode) }) {
					logger.info("Network \(networkConfig.networkName) started by the privileged helper with PID=\(pid)")

					let running = RunningNetworkProcess.helper(pid: pid)

					Thread.detachNewThread {
						while running.isRunning {
							Thread.sleep(forTimeInterval: 1)
						}

						logger.debug("Network process \(pid) died")
						kill(getpid(), SIGUSR2)
					}

					return running
				}
			}
		#endif

		if direct {
			runningArguments = []
			process.executableURL = executableURL
			process.standardInput = FileHandle.standardInput
			process.sharedFileHandles = [FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: false)]
		} else {
			let launch = try SudoCaked.privilegedLaunch(binary: executableURL, runMode: runMode)

			environment = launch.environment
			runningArguments = launch.arguments
			process.executableURL = launch.executableURL

			if launch.viaSudo {
				fd = STDIN_FILENO
				// We need to use the file descriptor of stdin, otherwise the process will not be able to read from it and will block forever
				process.standardInput = FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: false)
			} else {
				// setuid-root caked: no sudo in between, so the descriptor is inherited like for an unprivileged start
				process.standardInput = FileHandle.standardInput
				process.sharedFileHandles = [FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: false)]
			}
		}

		arguments.append("--fd=\(fd)")
		arguments.append("--pidfile=\(pidFile.path(percentEncoded: false))")

		runningArguments.append(contentsOf: arguments)

		#if DEBUG
			logger.debug("Running: \(process.executableURL!.path(percentEncoded: false)) \(runningArguments.joined(separator: " "))")
		#endif

		try? pidFile.delete()

		process.arguments = runningArguments
		process.environment = environment
		process.standardOutput = FileHandle.standardOutput
		process.standardError = FileHandle.standardError
		process.terminationHandler = { process in
			#if DEBUG
				logger.debug("Process died: \(process.terminationStatus), \(process.terminationReason)")
			#endif
			kill(getpid(), SIGUSR2)
		}

		try process.run()
		try pidFile.waitPID {
			if process.isRunning {
				logger.info("Network \(networkConfig.networkName) started")
			} else {
				if process.terminationReason == .uncaughtSignal {
					throw ServiceError(String(localized: "Network \(networkConfig.networkName) failed to start: \(process.terminationStatus), \(process.terminationReason.rawValue)"))
				} else {
					throw ServiceError(String(localized: "Network \(networkConfig.networkName) stopped: \(process.terminationStatus)"))
				}
			}
		}

		return .process(process)
	}

	public static func run(mode: VMNetMode, networkConfig: UsedNetworkConfig, socketPath: URL? = nil, pidFile: URL? = nil, runMode: Utils.RunMode) throws {
		let socketURL: (socket: URL, pidFile: URL)
		let executableURL: URL
		let debug = Logger.Level() >= .debug
		var arguments: [String] = []

		if let socketPath = socketPath, let pidFile = pidFile {
			socketURL = (socketPath.absoluteURL, pidFile.absoluteURL)
		} else {
			socketURL = try NetworksHandler.vmnetEndpoint(networkName: networkConfig.networkName, runMode: runMode)
		}

		Logger(self).info("Start VMNet mode: \(mode.rawValue) Using socket: \(socketURL.socket.path(percentEncoded: false))")

		executableURL = try Bundle.main.caked()

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
			guard networkConfig.networkName != String.empty else {
				throw ServiceError(String(localized: "interface is required for bridged mode"))
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

			if networkConfig.dns == true {
				arguments.append("--dns")
			}
		}

		arguments.append("--pidfile=\(socketURL.pidFile.path(percentEncoded: false))")
		arguments.append(socketURL.socket.path(percentEncoded: false))

		if socketURL.pidFile.isCakedRunning() {
			throw ServiceError(String(localized: "\(executableURL.path(percentEncoded: false)) is already running."))
		}

		try? socketURL.socket.delete()

		let process = try Bundle.createProcess()
		var runningArguments: [String]
		let logger = Logger(self)

		var environment = try Utilities.environment(runMode: runMode)

		if NetworksHandler.canManageNetworkWithoutRoot(mode: mode) {
			process.executableURL = executableURL
			runningArguments = []
		} else {
			let launch = try SudoCaked.privilegedLaunch(binary: executableURL, runMode: runMode)

			environment = launch.environment
			process.executableURL = launch.executableURL
			runningArguments = launch.arguments
		}

		runningArguments.append(contentsOf: arguments)

		logger.debug("Running: \(process.executableURL!.path(percentEncoded: false)) \(runningArguments.joined(separator: " "))")

		process.arguments = runningArguments
		process.environment = environment
		process.standardInput = FileHandle.nullDevice
		process.terminationHandler = { process in
			#if DEBUG
				logger.debug("Process terminated: \(process.terminationStatus), \(process.terminationReason)")
			#endif
			kill(getpid(), SIGUSR2)
		}

		if debug {
			process.standardOutput = FileHandle.standardOutput
			process.standardError = FileHandle.standardError
		} else {
			let output = try Self.vmnetFileLog(socketURL.socket)

			process.standardOutput = output
			process.standardError = output
		}

		try process.run()
		try socketURL.pidFile.waitPID {
			if process.isRunning {
				logger.info("Network \(networkConfig.networkName) started")
			} else {
				if process.terminationReason == .uncaughtSignal {
					throw ServiceError(String(localized: "Network \(networkConfig.networkName) failed to start: \(process.terminationStatus), \(process.terminationReason.rawValue)"))
				} else {
					throw ServiceError(String(localized: "Network \(networkConfig.networkName) stopped: \(process.terminationStatus)"))
				}
			}
		}
	}

	public static func configure(networkName: String, network: VZSharedNetwork, runMode: Utils.RunMode) -> ConfiguredNetworkReply {
		do {
			// "nat" and "imds" are always derived (VZVMNetConfig.sharedNetworks
			// recomputes them from defaultNatNetwork/defaultImdsNetwork on every access),
			// so any override written here would be silently discarded on the next read.
			// Reject up front rather than reporting a misleading "configured: true".
			guard networkName != BridgeAttachement.defaultNetworkName, networkName != IMDSNetworkInterface.imdsNetworkName else {
				throw ServiceError(String(localized: "Network \(networkName) is a reserved default network and cannot be configured"))
			}

			let home: Home = try Home(runMode: runMode)
			var networkConfig = try home.sharedNetworks()

			guard let existing = networkConfig.sharedNetworks[networkName] else {
				throw ServiceError(String(localized: "Network \(networkName) doesn't exists"))
			}

			if existing == network {
				return ConfiguredNetworkReply(name: networkName, configured: false, reason: String(localized: "Network \(networkName) unchanged"))
			}

			networkConfig.userNetworks[networkName] = network
			try home.setSharedNetworks(networkConfig)

			do {
				return ConfiguredNetworkReply(name: networkName, configured: true, reason: try self.restartNetworkService(networkName: networkName, runMode: runMode))
			} catch {
				return ConfiguredNetworkReply(name: networkName, configured: true, reason: error.reason)
			}
		} catch {
			return ConfiguredNetworkReply(name: networkName, configured: false, reason: error.reason)
		}
	}

	public static func configure(network: UsedNetworkConfig, runMode: Utils.RunMode) -> ConfiguredNetworkReply {
		do {
			let home: Home = try Home(runMode: runMode)
			var networkConfig = try home.sharedNetworks()

			guard network.networkName != String.empty else {
				return ConfiguredNetworkReply(name: String.empty, configured: false, reason: String(localized: "Network name is required"))
			}

			guard Self.isPhysicalInterface(name: String(network.networkName)) == false else {
				return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: String(localized: "Network \(network.networkName) is a physical interface"))
			}

			guard let exisiting = networkConfig.sharedNetworks[network.networkName] else {
				return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: String(localized: "Network \(network.networkName) doesn't exists"))
			}

			let netmask = network.netmask ?? exisiting.netmask
			// A new start address without an end: default the end to the last address of the network.
			let dhcpEnd = network.dhcpEnd ?? (network.dhcpStart.flatMap { VZSharedNetwork.defaultDhcpEnd(dhcpStart: $0, netmask: netmask) } ?? exisiting.dhcpEnd)

			let changed = VZSharedNetwork(
				mode: exisiting.mode,
				netmask: netmask,
				dhcpStart: network.dhcpStart ?? exisiting.dhcpStart,
				dhcpEnd: dhcpEnd,
				dhcpLease: network.dhcpLease ?? exisiting.dhcpLease,
				interfaceID: network.interfaceID ?? exisiting.interfaceID,
				nat66Prefix: network.nat66Prefix ?? exisiting.nat66Prefix,
				dns: network.dns ?? exisiting.dns ?? false
			)

			if changed != exisiting {
				try changed.validate(runMode: runMode, excluding: network.networkName)
				networkConfig.userNetworks[network.networkName] = changed
				try home.setSharedNetworks(networkConfig)

				do {
					return ConfiguredNetworkReply(name: network.networkName, configured: true, reason: try self.restartNetworkService(networkName: network.networkName, runMode: runMode))
				} catch {
					return ConfiguredNetworkReply(name: network.networkName, configured: true, reason: error.reason)
				}
			} else {
				return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: String(localized: "Network \(network.networkName) unchanged"))
			}
		} catch {
			return ConfiguredNetworkReply(name: network.networkName, configured: false, reason: error.reason)
		}
	}

	public static func start(networkName: String, runMode: Utils.RunMode) -> StartedNetworkReply {
		do {
			_ = try startNetwork(networkName: networkName, runMode: runMode)

			return StartedNetworkReply(name: networkName, started: true, reason: String(localized: "Network \(networkName) started"))
		} catch {
			return StartedNetworkReply(name: networkName, started: false, reason: error.reason)
		}
	}

	public static func startNetwork(networkName: String, runMode: Utils.RunMode) throws -> (URL, URL) {
		let home: Home = try Home(runMode: runMode)
		let sharedNetworks = try home.sharedNetworks().sharedNetworks
		let socketURL: (socket: URL, pidFile: URL)
		let isPhysicalInterface = Self.isPhysicalInterface(name: networkName)
		let canManageNetworkWithoutRoot: Bool

		if isPhysicalInterface {
			if CakedLib.NetworksHandler.hasVMNetEntitlement {
				throw ServiceError(String(localized: "Network \(networkName) is handled natively, please use a different network"))
			}

			canManageNetworkWithoutRoot = CakedLib.NetworksHandler.canManageNetworkWithoutRoot(mode: VMNetMode.bridged)
			socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)
		} else {
			guard let network = sharedNetworks[networkName] else {
				throw ServiceError(String(localized: "Network \(networkName) doesn't exists"))
			}

			canManageNetworkWithoutRoot = CakedLib.NetworksHandler.canManageNetworkWithoutRoot(mode: network.mode)
			socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)
		}

		if socketURL.pidFile.isCakedRunning() {
			if let pid = socketURL.pidFile.readPID() {
				Logger(self).info("Network \(networkName) is already running with PID=\(pid)")
			} else {
				Logger(self).info("Network \(networkName) is already running with undetermined PID")
			}

			return socketURL
		}

		try? socketURL.pidFile.deleteIfFileExists()
		try? socketURL.socket.deleteIfFileExists()

		Logger(self).info("Start network: \(networkName) using socket: \(socketURL.socket.path(percentEncoded: false))")

		#if USE_AUTHORIZATION_HELPER
			if canManageNetworkWithoutRoot == false {
				// The helper starts it as root and replies once the network wrote its pid file.
				if try DirectAuthorizationHelperConnector.viaHelperSync(runMode: runMode, { try await $0.startNetwork(networkName: networkName, runMode: runMode) }) != nil {
					Logger(self).info("Network \(networkName) started by the privileged helper")

					return socketURL
				}
			}
		#endif

		let executableURL = try Bundle.main.caked()

		var arguments = ["networks", "start", "--fork", networkName]
		let process = try Bundle.createProcess()
		var runningArguments: [String]
		let debug = Logger.Level() >= .debug
		let logger = Logger(self)

		if Logger.LoggingLevel() > .info {
			arguments.append("--log-level=\(Logger.LoggingLevel().rawValue)")
		}

		if runMode.isSystem {
			arguments.append("--system")
		}

		try? socketURL.socket.delete()

		var environment = try Utilities.environment(runMode: runMode)

		if canManageNetworkWithoutRoot {
			process.executableURL = executableURL
			runningArguments = []
		} else {
			let launch = try SudoCaked.privilegedLaunch(binary: executableURL, runMode: runMode)

			environment = launch.environment
			process.executableURL = launch.executableURL
			runningArguments = launch.arguments
		}

		runningArguments.append(contentsOf: arguments)

		#if DEBUG
			logger.debug("Running: \(process.executableURL!.path(percentEncoded: false)) \(runningArguments.joined(separator: " "))")
		#endif

		process.arguments = runningArguments
		process.environment = environment
		process.standardInput = FileHandle.nullDevice
		process.terminationHandler = { process in
			if process.terminationReason == .uncaughtSignal {
				logger.info("Network \(networkName) terminated: \(process.terminationStatus), \(process.terminationReason)")
			} else {
				logger.info("Network \(networkName) exited: \(process.terminationStatus)")
			}
		}

		if debug {
			process.standardOutput = FileHandle.standardOutput
			process.standardError = FileHandle.standardError
		} else {
			let output = try Self.vmnetFileLog(socketURL.socket)

			process.standardOutput = output
			process.standardError = output
		}

		try process.run()

		try socketURL.pidFile.waitPID {
			if process.isRunning {
				logger.info("Network \(networkName) started")
			} else {
				logger.error("Network \(networkName) failed to start: \(process.terminationStatus), \(process.terminationReason.rawValue)")

				if process.terminationReason == .uncaughtSignal {
					throw ServiceError(String(localized: "Network \(networkName) failed to start: \(process.terminationStatus), \(process.terminationReason.rawValue)"))
				} else {
					throw ServiceError(String(localized: "Network \(networkName) stopped: \(process.terminationStatus)"))
				}
			}
		}

		return socketURL
	}

	public static func run(networkName: String, runMode: Utils.RunMode) throws -> (URL, URL) {
		let home: Home = try Home(runMode: runMode)
		let sharedNetworks = try home.sharedNetworks().sharedNetworks
		let socketURL: (socket: URL, pidFile: URL)
		let mode: VMNetMode
		let networkConfig: UsedNetworkConfig

		if Self.isPhysicalInterface(name: networkName) {
			socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)
			mode = .bridged
			networkConfig = .init(name: networkName)
		} else {
			guard let network = sharedNetworks[networkName] else {
				throw ServiceError(String(localized: "Network \(networkName) doesn't exists"))
			}

			mode = networkName == "host" ? .host : .shared
			socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)
			networkConfig = UsedNetworkConfig(name: networkName, config: network)
		}

		try Self.run(mode: mode, networkConfig: networkConfig, socketPath: socketURL.socket, pidFile: socketURL.pidFile, runMode: runMode)

		return socketURL
	}

	public static func create(networkName: String, network: VZSharedNetwork, runMode: Utils.RunMode) -> CreatedNetworkReply {
		do {
			let home: Home = try Home(runMode: runMode)
			var networkConfig = try home.sharedNetworks()

			if networkConfig.sharedNetworks[networkName] != nil {
				return CreatedNetworkReply(name: networkName, created: false, reason: String(localized: "Network \(networkName) already exists"))
			}

			networkConfig.userNetworks[networkName] = network

			try home.setSharedNetworks(networkConfig)

			return CreatedNetworkReply(name: networkName, created: true, reason: String(localized: "Network \(networkName) created"))
		} catch {
			return CreatedNetworkReply(name: networkName, created: false, reason: error.reason)
		}
	}

	public static func delete(networkName: String, runMode: Utils.RunMode) -> DeleteNetworkReply {
		do {
			let home: Home = try Home(runMode: runMode)
			var networkConfig = try home.sharedNetworks()

			guard networkConfig.sharedNetworks[networkName] != nil else {
				return DeleteNetworkReply(name: networkName, deleted: false, reason: String(localized: "Network \(networkName) doesn't exists"))
			}

			let socketURL = try NetworksHandler.vmnetEndpoint(networkName: networkName, runMode: runMode)

			if socketURL.pidFile.isCakedRunning() {
				return DeleteNetworkReply(name: networkName, deleted: false, reason: String(localized: "Network \(networkName) is running"))
			}

			networkConfig.userNetworks.removeValue(forKey: networkName)

			try home.setSharedNetworks(networkConfig)

			return DeleteNetworkReply(name: networkName, deleted: true, reason: String(localized: "Network \(networkName) deleted"))
		} catch {
			return DeleteNetworkReply(name: networkName, deleted: false, reason: error.reason)
		}
	}

	public static func vmnetFileLog(_ socketURL: URL) throws -> FileHandle {
		let logURL = socketURL.deletingPathExtension().appendingPathExtension("log")
		let logPath = logURL.path(percentEncoded: false)

		if FileManager.default.fileExists(atPath: logPath) {
			try FileManager.default.removeItem(atPath: logPath)
		}

		FileManager.default.createFile(atPath: logPath, contents: nil)

		return try FileHandle(forWritingTo: logURL)
	}

	public static func vmnetFileLog(networkName: String, runMode: Utils.RunMode) throws -> FileHandle {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)

		return try Self.vmnetFileLog(socketURL.socket)
	}

	public static func stop(pidURL: URL, runMode: Utils.RunMode) -> String {
		do {
			guard try pidURL.exists() else {
				throw ServiceError(String(localized: "PID file \(pidURL.path(percentEncoded: false)) doesn't exists"))
			}

			guard pidURL.isCakedRunning() else {
				#if DEBUG
					Logger(self).debug("PID \(pidURL.path(percentEncoded: false)) is not running")
				#endif
				return "PID \(pidURL.path(percentEncoded: false)) is not running"
			}

			let client = try Self.getVMNetControlClient(pidURL, runMode: runMode)

			defer {
				try? client.channel.close().wait()
			}

			_ = try client.stop(.init()).response.wait()

			return "PID \(pidURL.path(percentEncoded: false)) stopped"
		} catch {
			return error.reason
		}
	}

	public static func stop(networkName: String, checkIfUsed: Bool, runMode: Utils.RunMode) -> StoppedNetworkReply {
		do {
			return StoppedNetworkReply(name: networkName, stopped: true, reason: try stopNetwork(networkName: networkName, checkIfUsed: checkIfUsed, runMode: runMode))
		} catch {
			return StoppedNetworkReply(name: networkName, stopped: false, reason: error.reason)
		}
	}

	public static func stopAll(runMode: Utils.RunMode) -> [StoppedNetworkReply] {
		let networks = NetworksHandler.networks(all: true, runMode: runMode)

		if networks.success {
			return networks.networks.filter {
				$0.running
			}.map { network in
				if network.usedBy.active == 0 {
					return stop(networkName: network.name, checkIfUsed: false, runMode: runMode)
				} else {
					return StoppedNetworkReply(name: network.name, stopped: false, reason: String(localized: "Network \(network.name) is currently in use by one or more virtual machines"))
				}
			}
		} else {
			return [StoppedNetworkReply(name: "<all>", stopped: false, reason: networks.reason)]
		}
	}

	private static func stopNetwork(networkName: String, checkIfUsed: Bool, runMode: Utils.RunMode) throws -> String {
		let socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)

		if checkIfUsed {
			guard CakedLib.NetworksHandler.referencedNetwork(networkName: networkName, runMode: runMode).active == 0 else {
				throw ServiceError(String(localized: "Network \(networkName) is currently in use by one or more virtual machines"))
			}
		}

		let pidURL = socketURL.pidFile

		guard pidURL.isCakedRunning() else {
			Logger(self).info("Network \(networkName) is not running")
			return "Network \(networkName) is not running"
		}

		let client = try Self.getVMNetControlClient(pidURL, runMode: runMode)

		defer {
			try? client.channel.close().wait()
		}

		_ = try client.stop(.init()).response.wait()

		return "Network \(networkName) stopped"
	}

	private static var _defaultNatNetwork: BridgedNetwork?

	public static func defaultNatNetwork(runMode: Utils.RunMode) -> BridgedNetwork {
		let referencedNetworks = Self.referencedNetworks(runMode: runMode)

		if var defaultNatNetwork = self._defaultNatNetwork {
			defaultNatNetwork.usedBy = referencedNetworks.usage(name: BridgeAttachement.defaultNetworkName)

			return defaultNatNetwork
		}

		var dhcpEnd = String.empty
		var dhcpLease = String.empty

		if let lease = try? getDHCPLease() {
			dhcpLease = "\(lease)"
		}

		if let network = BridgeAttachement.defaultNetworkGateway.toNetwork() {
			dhcpEnd = "\(network.range.upperBound.description)/\(network.bits)"
		}

		let defaultNatNetwork = BridgedNetwork(
			name: BridgeAttachement.defaultNetworkName,
			mode: .nat,
			description: BridgeAttachement.defaultNetworkName,
			gateway: BridgeAttachement.defaultNetworkGateway,
			dhcpEnd: dhcpEnd,
			dhcpLease: dhcpLease,
			interfaceID: BridgeAttachement.defaultNetworkUUID,
			endpoint: String.empty,
			running: false,
			managed: false,
			dns: true,
			usedBy: referencedNetworks.usage(name: BridgeAttachement.defaultNetworkName))

		self._defaultNatNetwork = defaultNatNetwork

		return defaultNatNetwork
	}

	public static func referencedNetwork(networkName: String, runMode: Utils.RunMode) -> BridgedNetwork.NetworkUsage {
		var usage = BridgedNetwork.NetworkUsage(used: 0, active: 0)

		guard let list = try? StorageLocation(runMode: runMode).list() else {
			return usage
		}

		list.values.forEach { location in
			let running = location.status.isRunning

			if let config = try? location.config() {
				config.qualifiedNetworks.forEach { network in
					if networkName == network.network {
						usage.used += 1

						if running {
							usage.active += 1
						}
					}
				}
			}
		}

		return usage
	}

	public static func referencedNetworks(runMode: Utils.RunMode) -> ReferencedNetworks {
		var usedNetworks: ReferencedNetworks = ReferencedNetworks()

		guard let list = try? StorageLocation(runMode: runMode).list() else {
			return usedNetworks
		}

		list.values.forEach { location in
			let running = location.status.isRunning

			if let config = try? location.config() {
				func reference(_ name: String) {
					if var count = usedNetworks[name] {
						count.used += 1

						if running {
							count.active += 1
						}

						usedNetworks[name] = count
					} else {
						usedNetworks[name] = BridgedNetwork.NetworkUsage(used: 1, active: running ? 1 : 0)
					}
				}

				// Config doesn't include imds network, but if the VM is running and has imds enabled, we need to count it as a reference.
				// Assume that a network interface is connected to the imds network.
				if IMDSNetworkInterface.imdsEnabled {
					reference(IMDSNetworkInterface.imdsNetworkName)
				}

				config.qualifiedNetworks.forEach { network in
					reference(network.network)
				}
			}
		}

		return usedNetworks
	}

	public static func networks(all: Bool = false, runMode: Utils.RunMode) -> ListNetworksReply {
		do {
			var networks: [BridgedNetwork] = []
			let home: Home = try Home(runMode: runMode)
			let networkConfig = try home.sharedNetworks()
			let referencedNetworks = Self.referencedNetworks(runMode: runMode)
			let networkInterfaces = VZSharedNetwork.networkInterfaces(includeSharedNetworks: false, runMode: runMode)

			func createBridgedNetwork(_ name: String, _ mode: BridgedNetworkMode, _ description: String, _ uuid: String, _ gateway: String, _ dhcpEnd: String, _ dhcpLease: String, _ dns: Bool) throws -> BridgedNetwork {
				let socketURL = try NetworksHandler.vmnetEndpoint(networkName: name, runMode: runMode)
				let endpoint: String
				let running = socketURL.pidFile.isPIDRunning().running
				let managed = mode == .bridged ? NetworksHandler.hasVMNetEntitlement == false : true

				if try socketURL.socket.exists() {
					endpoint = socketURL.socket.path(percentEncoded: false)
				} else {
					endpoint = String.empty
				}

				return BridgedNetwork(
					name: name,
					mode: mode,
					description: description,
					gateway: gateway,
					dhcpEnd: dhcpEnd,
					dhcpLease: dhcpLease,
					interfaceID: uuid,
					endpoint: endpoint,
					running: running,
					managed: managed,
					dns: dns,
					usedBy: referencedNetworks.usage(name: name))
			}

			try networks.append(
				contentsOf: VZBridgedNetworkInterface.networkInterfaces.map { inf in
					if let address = networkInterfaces[inf.identifier] {
						return try createBridgedNetwork(
							inf.identifier,
							.bridged,
							inf.localizedDisplayName ?? inf.identifier,
							String.empty,
							address.network.description,
							"\(address.range.upperBound.description)/\(address.network.bits)",
							String.empty,
							false)
					} else {
						return try createBridgedNetwork(
							inf.identifier,
							.bridged,
							inf.localizedDisplayName ?? inf.identifier,
							String.empty,
							String.empty,
							String.empty,
							String.empty,
							false)
					}
				})

			let dhcpLease = networkConfig.defaultNatNetwork.dhcpLease != nil ? "\(networkConfig.defaultNatNetwork.dhcpLease!)" : String.empty

			networks = try networkConfig.sharedNetworks.filter({ $1.visible || all }).reduce(into: networks) {
				let cidr = $1.value.netmask.netmaskToCidr()
				let gateway = "\($1.value.dhcpStart)/\(cidr)"
				let dhcpEnd = "\($1.value.dhcpEnd)/\(cidr)"
				let uuid = $1.value.interfaceID
				let dns = $1.value.dns ?? false
				let networkLease = $1.value.dhcpLease.map { "\($0)" } ?? dhcpLease

				$0.append(try createBridgedNetwork($1.key, .init($1.value.mode), $1.value.mode.description, uuid, gateway, dhcpEnd, networkLease, dns))
			}.sorted {
				$0 < $1
			}

			return ListNetworksReply(networks: networks, success: true, reason: String(localized: "Success"))
		} catch {
			return ListNetworksReply(networks: [], success: false, reason: error.reason)
		}
	}

	public static func status(networkName: String, runMode: Utils.RunMode) -> NetworkInfoReply {
		let referencedNetworks = Self.referencedNetworks(runMode: runMode)
		var result: BridgedNetwork
		var mode: BridgedNetworkMode = .shared
		var description: String = String.empty
		var uuid: String = String.empty
		var gateway: String = String.empty
		var dhcpEnd: String = String.empty
		var dhcpLease: String = String.empty
		var endpoint: String = String.empty
		var managed = true
		var dns = false

		if let inf = NetworksHandler.findPhysicalInterface(name: networkName) {
			let interfaces = VZSharedNetwork.networkInterfaces(includeSharedNetworks: false, runMode: runMode)

			if let network = interfaces[networkName] {
				gateway = network.network.description
				dhcpEnd = "\(network.range.upperBound.description)/\(network.network.bits)"
			}

			mode = .bridged
			description = inf.localizedDisplayName ?? inf.identifier
			uuid = inf.identifier
			managed = NetworksHandler.hasVMNetEntitlement == false
		} else {
			guard let networkConfig = try? Home(runMode: runMode).sharedNetworks() else {
				return NetworkInfoReply(
					info: BridgedNetwork(
						name: String.empty,
						mode: .shared,
						description: String.empty,
						gateway: String.empty,
						dhcpLease: String.empty,
						interfaceID: String.empty,
						endpoint: String.empty,
						running: false,
						managed: false,
						dns: false,
						usedBy: BridgedNetwork.NetworkUsage(used: 0, active: 0)),
					success: false,
					reason: String(localized: "Unable to get the list of networks"))
			}

			guard let network = networkConfig.sharedNetworks[networkName] else {
				return NetworkInfoReply(
					info: BridgedNetwork(
						name: String.empty,
						mode: .shared,
						description: String.empty,
						gateway: String.empty,
						dhcpLease: String.empty,
						interfaceID: String.empty,
						endpoint: String.empty,
						running: false,
						managed: false,
						dns: false,
						usedBy: BridgedNetwork.NetworkUsage(used: 0, active: 0)),
					success: false,
					reason: String(localized: "Network \(networkName) doesn't exists"))
			}

			let cidr = network.netmask.netmaskToCidr()
			dns = network.dns ?? false
			mode = .init(network.mode)
			description = network.mode.description
			uuid = network.interfaceID
			gateway = "\(network.dhcpStart)/\(cidr)"
			dhcpEnd = "\(network.dhcpEnd)/\(cidr)"
			managed = mode != .nat
			#if !USE_DHCP_SERVER
				if let value = try? Self.getDHCPLease() {
					dhcpLease = "\(value)"
				}
			#else
				dhcpLease = network.dhcpLease.map { "\($0)" } ?? String.empty
			#endif
		}

		do {
			let socketURL = try Self.vmnetEndpoint(networkName: networkName, runMode: runMode)
			let running = socketURL.pidFile.isPIDRunning().running

			if try socketURL.socket.exists() && socketURL.pidFile.isPIDRunning().running {
				endpoint = socketURL.socket.path(percentEncoded: false)
			}

			result = BridgedNetwork(
				name: networkName,
				mode: mode,
				description: description,
				gateway: gateway,
				dhcpEnd: dhcpEnd,
				dhcpLease: dhcpLease,
				interfaceID: uuid,
				endpoint: endpoint,
				running: running,
				managed: managed,
				dns: dns,
				usedBy: referencedNetworks.usage(name: networkName))

			return NetworkInfoReply(info: result, success: true, reason: String(localized: "Success"))
		} catch {
			return NetworkInfoReply(
				info: BridgedNetwork(
					name: String.empty,
					mode: .shared,
					description: String.empty,
					gateway: String.empty,
					dhcpLease: String.empty,
					interfaceID: String.empty,
					endpoint: String.empty,
					running: false,
					managed: managed,
					dns: false,
					usedBy: BridgedNetwork.NetworkUsage(used: 0, active: 0)),
				success: false,
				reason: error.reason)
		}
	}

	public static func getVMNetControlClient(_ networkName: String, runMode: Utils.RunMode) throws -> Vmnet_VMNetServiceNIOClient {
		let home = try Home(runMode: runMode)
		let networkDirectory = home.networkDirectory.appendingPathComponent(networkName, isDirectory: true)

		return try getVMNetControlClient(networkDirectory.socketPath(name: "net"), runMode: runMode)
	}

	public static func getVMNetControlClient(_ socketURL: URL, runMode: Utils.RunMode) throws -> Vmnet_VMNetServiceNIOClient {
		let socketURL = socketURL.deletingLastPathComponent().appendingPathComponent(VZVMNetCommon.networkSocketControl)
		let certLocation = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		var clientConfiguration = ClientConnection.Configuration.default(
			target: .unixDomainSocket(socketURL.path(percentEncoded: false)),
			eventLoopGroup: Utilities.group)
		clientConfiguration.tlsConfiguration = try GRPCTLSConfiguration.makeClientConfiguration(
			caCert: certLocation.caCertURL.path(percentEncoded: false),
			tlsKey: certLocation.clientKeyURL.path(percentEncoded: false),
			tlsCert: certLocation.clientCertURL.path(percentEncoded: false))
		clientConfiguration.connectionBackoff = ConnectionBackoff(maximumBackoff: 5, minimumConnectionTimeout: 5, retries: .upTo(1))

		return Vmnet_VMNetServiceNIOClient(channel: ClientConnection(configuration: clientConfiguration))
	}
}

extension Caked_NetworkRequestNetworkMode {
	public init(_ from: VMNetMode) {
		switch from {
		case .host:
			self = .host
		case .shared:
			self = .shared
		default:
			self = .UNRECOGNIZED(Int(from.integerValue))
		}
	}
}
