import Foundation
import GRPCLib
import NIOPortForwarding
import Virtualization

public typealias DisplaySize = [String: Int]

extension DisplaySize {
	public var width: Int {
		set { self["width"] = newValue }
		get { self["width"]! }
	}

	public var height: Int {
		set { self["height"] = newValue }
		get { self["height"]! }
	}

	public init(width: Int, height: Int) {
		self.init()

		self.width = width
		self.height = height
	}
}

enum ConfigFileName: String {
	case config = "config.json"
	case cake = "cake.json"
}

public enum VirtualizedOS: String, Codable {
	case darwin
	case linux
}

public final class CakeConfig {
	var config: Config
	var cake: Config
	let location: URL

	internal final class Config {
		var data: [String: Any]
		var dirty: Bool

		init() {
			self.dirty = false
			self.data = [String: Any]()
		}

		init(contentsOf: URL) throws {
			self.dirty = false
			self.data = try Dictionary(contentsOf: contentsOf)
		}

		func save(to: URL) throws {
			if self.dirty {
				try self.data.write(to: to)
				self.dirty = false
			}
		}

		@inlinable public subscript(key: String) -> Any? {
			get {
				return self.data[key]
			}
			set {
				self.data[key] = newValue
				self.dirty = true
			}
		}
	}

	public var version: Int {
		set { self.config["version"] = newValue }
		get { self.config["version"] as! Int }
	}

	public var os: VirtualizedOS {
		set { self.config["os"] = newValue.rawValue }
		get {
			let os: String? = self.config["os"] as? String

			if let os = os {
				return VirtualizedOS(rawValue: os)!
			}

			return .linux
		}
	}

	public var arch: Architecture {
		set { self.config["arch"] = newValue.rawValue }
		get {
			let arch: String? = self.config["arch"] as? String

			if let arch = arch {
				return Architecture(rawValue: arch)
			}

			return Architecture.current()
		}
	}

	public var cpuCountMin: Int {
		set { self.config["cpuCountMin"] = newValue }
		get { self.config["cpuCountMin"] as! Int }
	}

	#if arch(arm64)
		public var ecid: VZMacMachineIdentifier {
			set {
				self.config["ecid"] = newValue.dataRepresentation.base64EncodedString()
			}
			get {
				if let ecid = self.config["ecid"] as? String {
					if let ecid = VZMacMachineIdentifier(dataRepresentation: Data(base64Encoded: ecid)!) {
						return ecid
					}
				}

				return VZMacMachineIdentifier()
			}
		}

		public var hardwareModel: VZMacHardwareModel? {
			set {
				self.config["hardwareModel"] = newValue!.dataRepresentation.base64EncodedString()
			}
			get {
				if let hardwareModel = self.config["hardwareModel"] as? String {
					if let hardwareModel = VZMacHardwareModel(dataRepresentation: Data(base64Encoded: hardwareModel)!) {
						return hardwareModel
					}
				}

				return nil
			}
		}
	#endif

	public var suspendable: Bool {
		set { self.cake["suspendable"] = newValue }
		get {
			if #available(macOS 14, *) {
				self.cake["suspendable"] as? Bool ?? false
			} else {
				false
			}
		}
	}

	public var cpuCount: Int {
		set { self.config["cpuCount"] = newValue }
		get { self.config["cpuCount"] as! Int }
	}

	public var memorySizeMin: UInt64 {
		set { self.config["memorySizeMin"] = newValue }
		get { self.config["memorySizeMin"] as! UInt64 }
	}

	public var memorySize: UInt64 {
		set { self.config["memorySize"] = newValue }
		get { self.config["memorySize"] as! UInt64 }
	}

	public var macAddress: VZMACAddress? {
		set { if let value = newValue { self.config["macAddress"] = value.string } else { self.config["macAddress"] = nil } }
		get {
			if let addr = self.config["macAddress"] as? String {
				return VZMACAddress(string: addr)
			}

			return nil
		}
	}

	public var source: VMBuilder.ImageSource {
		set { self.cake["source"] = newValue.description }
		get {
			if let source = self.cake["source"] as? String {
				return VMBuilder.ImageSource(stringValue: source)
			}

			return VMBuilder.ImageSource.cloud
		}
	}

	public var osName: String? {
		set { self.cake["osName"] = newValue }
		get { self.cake["osName"] as? String }
	}

	public var osRelease: String? {
		set { self.cake["osRelease"] = newValue }
		get { self.cake["osRelease"] as? String }
	}

	public var dynamicPortForwarding: Bool {
		set { self.cake["dynamicPortForwarding"] = newValue }
		get { self.cake["dynamicPortForwarding"] as? Bool ?? false }
	}

	public var displayRefit: Bool {
		set { self.config["displayRefit"] = newValue }
		get { self.config["displayRefit"] as? Bool ?? false }
	}

	public var instanceID: String {
		set { self.cake["instance-id"] = newValue }
		get { self.cake["instance-id"] as? String ?? UUID().uuidString }
	}

	public var dhcpClientID: String? {
		set { self.cake["dhcpClientID"] = newValue }
		get { self.cake["dhcpClientID"] as? String }
	}

	public var sshPrivateKeyPath: String? {
		set { self.cake["sshPrivateKey"] = newValue }
		get { self.cake["sshPrivateKey"] as? String }
	}

	public var sshPrivateKeyPassphrase: String? {
		set { self.cake["sshPrivateKeyPassphrase"] = newValue }
		get { self.cake["sshPrivateKeyPassphrase"] as? String }
	}

	public var configuredUser: String {
		set { self.cake["configuredUser"] = newValue }
		get { self.cake["configuredUser"] as? String ?? "admin" }
	}

	public var configuredPassword: String? {
		set { self.cake["configuredPassword"] = newValue }
		get { self.cake["configuredPassword"] as? String }
	}

	public var autostart: Bool {
		set { self.cake["autostart"] = newValue }
		get { self.cake["autostart"] as? Bool ?? false }
	}

	public var agent: Bool {
		set { self.cake["agent"] = newValue }
		get { self.cake["agent"] as? Bool ?? false }
	}

	public var firstLaunch: Bool {
		set { self.cake["firstLaunch"] = newValue }
		get { self.cake["firstLaunch"] as? Bool ?? true }
	}

	public var nested: Bool {
		set { self.cake["nested"] = newValue }
		get { self.cake["nested"] as? Bool ?? false }
	}

	public var attachedDisks: [DiskAttachement] {
		set { self.cake["disks"] = newValue.map { $0.description } }
		get {
			guard let mounts: [String] = self.cake["disks"] as? [String] else {
				return []
			}

			return mounts.compactMap { DiskAttachement(argument: $0) }
		}
	}

	public var mounts: [DirectorySharingAttachment] {
		set { self.cake["mounts"] = newValue.map { $0.description } }
		get {
			guard let mounts: [String] = self.cake["mounts"] as? [String] else {
				return []
			}

			return mounts.compactMap { DirectorySharingAttachment(argument: $0) }
		}
	}

	public var networks: [BridgeAttachement] {
		set { self.cake["networks"] = newValue.map { $0.description } }
		get {
			guard let networks: [String] = self.cake["networks"] as? [String] else {
				return []
			}

			return networks.compactMap { BridgeAttachement(argument: $0) }
		}
	}

	public var qualifiedNetworks: [BridgeAttachement] {
		let networks = self.networks
		var attachedNetworks: [BridgeAttachement] = []

		if let nat = networks.first(where: { $0.isNAT() }) {
			attachedNetworks.append(nat)
		} else {
			attachedNetworks.append(BridgeAttachement(network: "nat", mode: .auto, macAddress: self.macAddress?.string))
		}

		attachedNetworks.append(contentsOf: networks.filter({ $0.isNAT() == false }))

		return attachedNetworks
	}

	public var useCloudInit: Bool {
		set { self.cake["cloud-init"] = newValue }
		get { self.cake["cloud-init"] as? Bool ?? false }
	}

	public var sockets: [SocketDevice] {
		set { self.cake["sockets"] = newValue.map { $0.description } }
		get {
			guard let mounts: [String] = self.cake["sockets"] as? [String] else {
				return []
			}

			return mounts.compactMap { SocketDevice(argument: $0) }
		}
	}

	public var console: ConsoleAttachment? {
		set { self.cake["console"] = newValue?.description }
		get {
			guard let consoleURL: String = self.cake["console"] as? String else {
				return nil
			}

			return ConsoleAttachment(argument: consoleURL)
		}
	}

	public var forwardedPorts: [TunnelAttachement] {
		set { self.cake["forwardedPorts"] = newValue.map { $0.description } }
		get {
			guard let mounts: [String] = self.cake["forwardedPorts"] as? [String] else {
				return []
			}

			return mounts.compactMap { TunnelAttachement(argument: $0) }
		}
	}

	public var runningIP: String? {
		set { self.cake["runningIP"] = newValue }
		get { self.cake["runningIP"] as? String ?? nil }
	}

	public var nestedVirtualization: Bool {
		if self.os == .linux && Utils.isNestedVirtualizationSupported() {
			return self.nested
		}

		return false
	}

	public var display: DisplaySize {
		set { self.config["display"] = newValue }
		get { self.config["display"] as! DisplaySize }
	}

	public var linuxMounts: String {
		guard self.os == .linux else {
			return ""
		}

		return self.mounts.compactMap { mount in
			let target: String

			if let destination = mount.destination {
				target = "\(mount.name):\(destination)"
			} else {
				target = "\(mount.name):/mnt/shared/\(mount.human)"
			}

			let options = mount.options.joined(separator: ",")

			if options.isEmpty {
				return "--mount=\(target)"
			}

			return "--mount=\(target),\(options)"
		}.joined(separator: " ")
	}

	public var installAgent: Bool {
		let source = self.source

		if self.agent {
			return false
		}

		#if arch(arm64)
			if self.firstLaunch {
				return source != .iso && source != .ipsw
			} else if source == .iso || source == .ipsw {
				return true
			}

			return false
		#else
			return config.firstLaunch && source != .iso
		#endif
	}

	public var vncPassword: String {
		set { self.cake["vncPassword"] = newValue }
		get {
			guard let vncPassword = self.cake["vncPassword"] as? String else {
				let vncPassword = UUID().uuidString
				self.cake["vncPassword"] = vncPassword
				return vncPassword
			}

			return vncPassword
		}
	}

	public init(
		location: URL,
		os: VirtualizedOS,
		autostart: Bool,
		configuredUser: String,
		configuredPassword: String?,
		displayRefit: Bool,
		cpuCountMin: Int,
		memorySizeMin: UInt64,
		macAddress: VZMACAddress = VZMACAddress.randomLocallyAdministered()
	) {

		var display = DisplaySize()

		display.width = 1024
		display.height = 768

		self.location = location
		self.config = Config()
		self.cake = Config()
		self.version = 1
		self.os = os
		self.cpuCountMin = cpuCountMin
		self.memorySizeMin = memorySizeMin
		self.macAddress = macAddress
		self.cpuCount = cpuCountMin
		self.memorySize = memorySizeMin
		self.displayRefit = displayRefit
		self.configuredUser = configuredUser
		self.configuredPassword = configuredPassword
		self.autostart = autostart
		self.display = display
		self.vncPassword = UUID().uuidString
	}

	public init(location: URL, configuredUser: String, configuredPassword: String) throws {
		self.location = location
		self.config = try Config(contentsOf: self.location.appendingPathComponent(ConfigFileName.config.rawValue))
		self.cake = Config()
		self.configuredUser = "admin"
		self.configuredPassword = "admin"
		self.autostart = false
		self.vncPassword = UUID().uuidString

		self.networks = []
		self.mounts = []
		self.sockets = []
		self.forwardedPorts = []
		self.attachedDisks = []
		self.firstLaunch = true
		self.useCloudInit = false
		self.agent = false
		self.instanceID = "i-\(String(format: "%x", Int(Date().timeIntervalSince1970)))"
	}

	public init(location: URL) throws {
		self.location = location
		self.config = try Config(contentsOf: self.location.appendingPathComponent(ConfigFileName.config.rawValue))
		self.cake = try Config(contentsOf: self.location.appendingPathComponent(ConfigFileName.cake.rawValue))
		
		if self.cake["vncPassword"] == nil {
			self.cake["vncPassword"] = UUID().uuidString

			try? self.save()
		}
	}

	public init(location: URL, options: BuildOptions) throws {
		self.location = location
		self.config = try Config(contentsOf: self.location.appendingPathComponent(ConfigFileName.config.rawValue))
		self.cake = Config()

		self.configuredUser = options.user
		self.configuredPassword = options.password
		self.autostart = options.autostart
		self.displayRefit = options.displayRefit
		self.autostart = autostart
		self.useCloudInit = false
		self.agent = false
		self.attachedDisks = options.attachedDisks
		self.vncPassword = UUID().uuidString

		if self.os == .darwin {
			self.cpuCount = max(Int(options.cpu), self.cpuCountMin)
			self.memorySize = max(options.memory * 1024 * 1024, UInt64(self.memorySizeMin))
		} else {
			self.cpuCount = Int(options.cpu)
			self.memorySize = options.memory * 1024 * 1024
			self.nested = options.nested
		}
	}

	public func save() throws {
		try self.config.save(to: self.location.appendingPathComponent(ConfigFileName.config.rawValue))
		try self.cake.save(to: self.location.appendingPathComponent(ConfigFileName.cake.rawValue))
	}

	public func resetMacAddress() {
		self.macAddress = VZMACAddress.randomLocallyAdministered()
	}

	public func platform(nvramURL: URL, needsNestedVirtualization: Bool) throws -> GuestPlateForm {
		switch self.os {
		#if arch(arm64)
			case .darwin:
				return DarwinPlateform(nvramURL: nvramURL, ecid: self.ecid, hardwareModel: self.hardwareModel!)
		#endif
		case .linux:
			return LinuxPlateform(nvramURL: nvramURL, needsNestedVirtualization: needsNestedVirtualization)
		#if !arch(arm64)
			default:
				throw ServiceError("Unsupported plateform")
		#endif
		}
	}
}

extension CakeConfig {
	public func startNetworkServices(runMode: Utils.RunMode) throws {
		let vmNetworking: Bool
		let home: Home = try Home(runMode: runMode)
		let networkConfig = try home.sharedNetworks()
		let sharedNetworks = networkConfig.sharedNetworks

		if let profile = try? EmbedProvisionProfile.load() {
			vmNetworking = profile.entitlements.vmNetworking
		} else {
			vmNetworking = false
		}

		try self.networks.forEach { inf in
			if inf.isNAT() == false {
				let physicalInterface = NetworksHandler.isPhysicalInterface(name: inf.network)

				if sharedNetworks[inf.network] == nil && physicalInterface == false {
					Logger(self).error("Network interface \(inf.network) not found")
				} else if (physicalInterface && vmNetworking) == false {
					try NetworksHandler.startNetworkService(networkName: inf.network, runMode: runMode)
				}
			}
		}
	}

	public func collectNetworks(runMode: Utils.RunMode) throws -> [NetworkAttachement] {
		let networks = self.qualifiedNetworks
		let vmNetworking: Bool
		let home: Home = try Home(runMode: runMode)
		let networkConfig = try home.sharedNetworks()
		let sharedNetworks = networkConfig.sharedNetworks

		if let profile = try? EmbedProvisionProfile.load() {
			vmNetworking = profile.entitlements.vmNetworking
		} else {
			vmNetworking = false
		}

		return networks.compactMap { inf in
			if inf.isNAT() {
				if let macAddress = self.macAddress {
					return NATNetworkInterface(macAddress: macAddress)
				}

				return NATNetworkInterface(macAddress: VZMACAddress.randomLocallyAdministered())
			} else {
				let macAddress: VZMACAddress

				if let strMacAddress = inf.macAddress, let mac = VZMACAddress(string: strMacAddress) {
					macAddress = mac
				} else {
					macAddress = VZMACAddress.randomLocallyAdministered()
				}

				if let networkConfig = sharedNetworks[inf.network] {
					return SharedNetworkInterface(macAddress: macAddress, networkName: inf.network, networkConfig: networkConfig)
				} else {
					let foundInterface = VZBridgedNetworkInterface.networkInterfaces.first {
						$0.identifier == inf.network || $0.localizedDisplayName == inf.network
					}

					if let interface = foundInterface {
						if vmNetworking {
							return BridgedNetworkInterface(interface: interface, macAddress: macAddress)
						} else {
							return VMNetworkInterface(interface: interface, macAddress: macAddress)
						}
					}
				}
			}

			// If we reach this point, the network interface was not found
			Logger(self).warn("Network interface \(inf.network) not found")

			return nil
		}
	}

	public func additionalDiskAttachments() throws -> [VZStorageDeviceConfiguration] {
		let cloudInit = URL(fileURLWithPath: cloudInitIso, relativeTo: self.location).absoluteURL
		var attachedDisks: [VZStorageDeviceConfiguration] = []

		attachedDisks.append(
			contentsOf: self.attachedDisks.compactMap {
				try? $0.configuration(relativeTo: self.location)
			})

		if try cloudInit.exists() {
			let attachment = try VZDiskImageStorageDeviceAttachment(url: cloudInit, readOnly: true, cachingMode: .cached, synchronizationMode: VZDiskImageSynchronizationMode.none)

			let cdrom = VZVirtioBlockDeviceConfiguration(attachment: attachment)

			cdrom.blockDeviceIdentifier = "CIDATA"

			attachedDisks.append(cdrom)
		}

		return attachedDisks
	}

	public func directorySharingAttachments() throws -> [VZDirectorySharingDeviceConfiguration] {
		return self.mounts.directorySharingAttachments(os: self.os)
	}

	public func socketDeviceAttachments(agentURL: URL) throws -> [SocketDevice] {
		let vsock = agentURL.absoluteURL.path
		var sockets: [SocketDevice] = [SocketDevice(mode: SocketMode.bind, port: 5000, bind: vsock)]

		if FileManager.default.fileExists(atPath: vsock) {
			try FileManager.default.removeItem(atPath: vsock)
		}

		sockets.append(contentsOf: self.sockets)

		return sockets
	}

	public func consoleAttachment() throws -> URL? {
		if let console = self.console {
			return try console.consoleURL(vmDir: self.location)
		}

		return nil
	}

	public func validAttachements(_ values: [DirectorySharingAttachment]) -> [DirectorySharingAttachment] {
		return self.mounts.compactMap { attachemnt in
			let description = attachemnt.description

			return values.first { $0.description == description }
		}
	}

	public func newAttachements(_ values: [DirectorySharingAttachment]) -> [DirectorySharingAttachment] {
		let mounts = self.mounts

		return values.compactMap { attachemnt in
			let description = attachemnt.description

			if mounts.contains(where: { $0.description == description }) {
				return nil
			}

			return attachemnt
		}
	}
}
