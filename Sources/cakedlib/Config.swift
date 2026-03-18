import Foundation
import GRPCLib
import NIOPortForwarding
import Virtualization
import CakeAgentLib

enum ConfigFileName: String {
	case config = "config.json"
	case cake = "cake.json"
}

public typealias DisplaySize = [String: Int]

extension DisplaySize {
	public var cgSize: CGSize {
		CGSize(width: CGFloat(width), height: CGFloat(height))
	}
	
	public var screenSize: ViewSize {
		ViewSize(width: width, height: height)
	}
	
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
	
	public init(viewSize: ViewSize) {
		self.init()

		self.width = viewSize.width
		self.height = viewSize.height
	}
}

public final class CakeConfig: VirtualMachineConfiguration {
	private var config: Config
	private var cake: Config

	public var diskSize: UInt64 = 0
	public var locationURL: URL

	internal final class Config {
		var data: [String: Any]
		var dirty: Bool

		var serializedRepresentation: Data? {
			self.data.jsonData
		}

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

	public var cpuCountMin: UInt16 {
		set { self.config["cpuCountMin"] = newValue }
		get { self.config["cpuCountMin"] as! UInt16 }
	}

	public var ecid: Data? {
		set {
			self.config["ecid"] = newValue?.base64EncodedString()
		}
		get {
			if let ecid = self.config["ecid"] as? String {
				return Data(base64Encoded: ecid)!
			}

			return nil
		}
	}

	public var hardwareModel: Data? {
		set {
			self.config["hardwareModel"] = newValue?.base64EncodedString()
		}
		get {
			if let hardwareModel = self.config["hardwareModel"] as? String {
				return Data(base64Encoded: hardwareModel)!
			}

			return nil
		}
	}

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

	public var cpuCount: UInt16 {
		set { self.config["cpuCount"] = newValue }
		get { self.config["cpuCount"] as! UInt16 }
	}

	public var memorySizeMin: UInt64 {
		set { self.config["memorySizeMin"] = newValue }
		get { self.config["memorySizeMin"] as! UInt64 }
	}

	public var memorySize: UInt64 {
		set { self.config["memorySize"] = newValue }
		get { self.config["memorySize"] as! UInt64 }
	}

	public var macAddress: String? {
		set {
			self.config["macAddress"] = newValue
		}
		get {
			self.config["macAddress"] as? String
		}
	}

	public var source: ImageSource {
		set { self.cake["source"] = newValue.description }
		get {
			if let source = self.cake["source"] as? String {
				return .init(stringValue: source)
			}

			return .qcow2
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
		set { self.cake["configuredPassword"] = try? newValue?.encrypt(key: "com.aldunelabs.com.caked") }
		get { try? (self.cake["configuredPassword"] as? String)?.decrypt(key: "com.aldunelabs.com.caked") }
	}

	public var configuredGroup: String {
		set { self.cake["configuredGroup"] = newValue }
		get { self.cake["configuredGroup"] as? String ?? "adm" }
	}

	public var configuredGroups: [String]? {
		set { self.cake["configuredGroups"] = newValue }
		get { self.cake["configuredGroups"] as? [String] }
	}

	public var configuredPlatform: SupportedPlatform {
		set { self.cake["configuredPlatform"] = newValue.rawValue }
		get { SupportedPlatform(stringValue: self.cake["configuredPlatform"] as? String) }
	}

	public var clearPassword: Bool {
		set { self.cake["clearPassword"] = newValue }
		get { self.cake["clearPassword"] as? Bool ?? false }
	}

	public var ifname: Bool {
		set { self.cake["ifname"] = newValue }
		get { self.cake["ifname"] as? Bool ?? false }
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

	public var mounts: DirectorySharingAttachments {
		set { self.cake["mounts"] = newValue.map { $0.description } }
		get {
			guard let mounts: [String] = self.cake["mounts"] as? [String] else {
				return []
			}

			return mounts.compactMap { DirectorySharingAttachment(argument: $0) }
		}
	}

	public var networks: [BridgeAttachement] {
		set {
			self.cake["networks"] = newValue.map(\.description)
		}
		get {
			guard let networks: [String] = self.cake["networks"] as? [String] else {
				return []
			}

			return networks.compactMap {
				if var network = BridgeAttachement(argument: $0)  {
					if network.isNAT() {
						network.macAddress = self.macAddress
					}

					return network
				}

				return nil
			}
		}
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

	public var console: String? {
		set { self.cake["console"] = newValue }
		get { self.cake["console"] as? String ?? nil }
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

	public var display: ViewSize {
		set {
			self.config["display"] = DisplaySize(viewSize: newValue)
		}
		get {
			if let display = self.config["display"] as? DisplaySize {
				return ViewSize(width: display.width, height: display.height)
			}

			return ViewSize.standard
		}
	}

	public var vncPassword: String? {
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
		configuredGroup: String,
		configuredGroups: [String]?,
		configuredPlatform: SupportedPlatform,
		clearPassword: Bool,
		displayRefit: Bool,
		ifname: Bool,
		cpuCountMin: UInt16,
		memorySize: UInt64,
		memorySizeMin: UInt64,
		macAddress: VZMACAddress = VZMACAddress.randomLocallyAdministered(),
		screenSize: ViewSize
	) {
		self.locationURL = location
		self.config = Config()
		self.cake = Config()
		self.version = 1
		self.os = os
		self.cpuCountMin = cpuCountMin
		self.memorySizeMin = memorySizeMin
		self.macAddress = macAddress.string
		self.cpuCount = cpuCountMin
		self.memorySize = memorySize
		self.memorySizeMin = memorySizeMin
		self.displayRefit = displayRefit
		self.configuredUser = configuredUser
		self.configuredPassword = configuredPassword
		self.configuredGroup = configuredGroup
		self.configuredGroups = configuredGroups
		self.configuredPlatform = configuredPlatform
		self.clearPassword = clearPassword
		self.ifname = ifname
		self.autostart = autostart
		self.display = screenSize
		self.vncPassword = UUID().uuidString
	}

	public init(location: URL, configuredUser: String, configuredPassword: String, configuredGroup: String, clearPassword: Bool) throws {
		self.locationURL = location
		self.config = try Config(contentsOf: self.locationURL.appendingPathComponent(ConfigFileName.config.rawValue))
		self.cake = Config()
		self.configuredUser = configuredUser
		self.configuredPassword = configuredPassword
		self.configuredGroup = configuredGroup
		self.autostart = false
		self.clearPassword = clearPassword
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
		self.locationURL = location
		self.config = try Config(contentsOf: self.locationURL.appendingPathComponent(ConfigFileName.config.rawValue))
		self.cake = try Config(contentsOf: self.locationURL.appendingPathComponent(ConfigFileName.cake.rawValue))

		if self.cake["vncPassword"] == nil {
			self.cake["vncPassword"] = UUID().uuidString

			try? self.save()
		}
	}

	public init(location: URL, options: BuildOptions) throws {
		self.locationURL = location
		self.config = try Config(contentsOf: self.locationURL.appendingPathComponent(ConfigFileName.config.rawValue))
		self.cake = Config()

		self.configuredUser = options.user
		self.configuredPassword = options.password
		self.configuredGroup = options.mainGroup
		self.configuredGroups = options.otherGroup
		self.configuredPlatform = SupportedPlatform(rawValue: options.image)
		self.ifname = options.netIfnames
		self.autostart = options.autostart
		self.displayRefit = options.displayRefit
		self.autostart = autostart
		self.useCloudInit = false
		self.agent = false
		self.attachedDisks = options.attachedDisks
		self.vncPassword = UUID().uuidString
		self.display = ViewSize(width: options.screenSize.width, height: options.screenSize.height)

		if self.os == .darwin {
			self.cpuCount = max(options.cpu, self.cpuCountMin)
			self.memorySize = max(options.memory * MoB, self.memorySizeMin)
		} else {
			self.cpuCount = options.cpu
			self.memorySize = options.memory * MoB
			self.nested = options.nested
		}
	}

	public init(config: VirtualMachineConfiguration) {
		self.locationURL = config.locationURL
		self.config = Config()
		self.cake = Config()

		self.locationURL = config.locationURL
		self.version = config.version
		self.os = config.os
		self.arch = config.arch
		self.cpuCountMin = config.cpuCountMin
		self.suspendable = config.suspendable
		self.diskSize = config.diskSize
		self.cpuCount = config.cpuCount
		self.memorySizeMin = config.memorySizeMin
		self.memorySize = config.memorySize
		self.macAddress = config.macAddress
		self.source = config.source
		self.osName = config.osName
		self.osRelease = config.osRelease
		self.dynamicPortForwarding = config.dynamicPortForwarding
		self.displayRefit = config.displayRefit
		self.instanceID = config.instanceID
		self.dhcpClientID = config.dhcpClientID
		self.sshPrivateKeyPath = config.sshPrivateKeyPath
		self.sshPrivateKeyPassphrase = config.sshPrivateKeyPassphrase
		self.configuredUser = config.configuredUser
		self.configuredPassword = config.configuredPassword
		self.configuredGroup = config.configuredGroup
		self.configuredGroups = config.configuredGroups
		self.configuredPlatform = config.configuredPlatform
		self.clearPassword = config.clearPassword
		self.ifname = config.ifname
		self.autostart = config.autostart
		self.agent = config.agent
		self.firstLaunch = config.firstLaunch
		self.nested = config.nested
		self.attachedDisks = config.attachedDisks
		self.mounts = config.mounts
		self.networks = config.networks
		self.useCloudInit = config.useCloudInit
		self.sockets = config.sockets
		self.console = config.console
		self.forwardedPorts = config.forwardedPorts
		self.runningIP = config.runningIP
		self.display = config.display
		self.vncPassword = config.vncPassword
		self.ecid = config.ecid
		self.hardwareModel = config.hardwareModel
	}

	public func save() throws {
		try self.config.save(to: self.locationURL.appendingPathComponent(ConfigFileName.config.rawValue))
		try self.cake.save(to: self.locationURL.appendingPathComponent(ConfigFileName.cake.rawValue))
	}

	public func fileWrapper() throws -> FileWrapper {
		guard let dataConfig = config.serializedRepresentation, let cakeData = cake.serializedRepresentation else {
			throw ServiceError("Failed to serialize config")
		}

		let config = FileWrapper(regularFileWithContents: dataConfig)
		let cake = FileWrapper(regularFileWithContents: cakeData)
		
		config.preferredFilename = ConfigFileName.config.rawValue
		cake.preferredFilename = ConfigFileName.cake.rawValue
		config.filename = ConfigFileName.config.rawValue
		cake.filename = ConfigFileName.cake.rawValue
		
		return FileWrapper(directoryWithFileWrappers: [
			ConfigFileName.config.rawValue: config,
			ConfigFileName.cake.rawValue: cake
		])
	}
}

extension CakeConfig {
	public func resetMacAddress() {
		self.macAddress = VZMACAddress.randomLocallyAdministered().string
		self.networks = self.networks.map {
			$0.clone()
		}
	}

	public func platform(nvramURL: URL, needsNestedVirtualization: Bool) throws -> GuestPlateForm {
		switch self.os {
		#if arch(arm64)
			case .darwin:
			return DarwinPlateform(nvramURL: nvramURL, ecid: self.getECID(), hardwareModel: self.getHardwareModel()!)
		#endif
		case .linux:
			return LinuxPlateform(nvramURL: nvramURL, needsNestedVirtualization: needsNestedVirtualization)
		#if !arch(arm64)
			default:
				throw ServiceError("Unsupported plateform")
		#endif
		}
	}

#if arch(arm64)
	public func setECID(_ ecid: VZMacMachineIdentifier) {
		self.ecid = ecid.dataRepresentation
	}

	public func getECID() -> VZMacMachineIdentifier {
		if let ecid = self.ecid {
			if let ecid = VZMacMachineIdentifier(dataRepresentation: ecid) {
				return ecid
			}
		}

		return VZMacMachineIdentifier()
	}

	public func setHardwareModel(_ model: VZMacHardwareModel) {
		self.hardwareModel = model.dataRepresentation
	}

	public func getHardwareModel() -> VZMacHardwareModel? {
		if let hardwareModel = self.hardwareModel {
			return VZMacHardwareModel(dataRepresentation: hardwareModel)
		}

		return nil
	}
#endif

}

extension VirtualMachineConfiguration {
	public func getMacAddress() -> VZMACAddress? {
		if let addr = self.macAddress {
			return VZMACAddress(string: addr)
		}

		return nil
	}

	public var nestedVirtualization: Bool {
		if self.os == .linux && Utils.isNestedVirtualizationSupported() {
			return self.nested
		}

		return false
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
			return self.firstLaunch && source != .iso
		#endif
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

	public var qualifiedNetworks: [BridgeAttachement] {
		let networks = self.networks
		var attachedNetworks: [BridgeAttachement] = []

		if let nat = networks.first(where: { $0.isNAT() }) {
			attachedNetworks.append(nat)
		} else {
			attachedNetworks.append(BridgeAttachement(network: "nat", mode: .auto, macAddress: self.macAddress))
		}

		attachedNetworks.append(contentsOf: networks.filter({ $0.isNAT() == false }))

		return attachedNetworks
	}

	public func startNetworkServices(runMode: Utils.RunMode) throws {
		try NetworksHandler.startNetworkServices(networks: self.networks, runMode: runMode)
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
				if let macAddress = self.getMacAddress() {
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
		let cloudInit = URL(fileURLWithPath: cloudInitIso, relativeTo: self.locationURL).absoluteURL
		var attachedDisks: [VZStorageDeviceConfiguration] = []

		attachedDisks.append(
			contentsOf: self.attachedDisks.compactMap {
				try? $0.configuration(relativeTo: self.locationURL)
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
			return try console.consoleURL(vmDir: self.locationURL)
		}

		return nil
	}

	public func validAttachements(_ values: DirectorySharingAttachments) -> DirectorySharingAttachments {
		return self.mounts.compactMap { attachemnt in
			let description = attachemnt.description

			return values.first { $0.description == description }
		}
	}

	public func newAttachements(_ values: DirectorySharingAttachments) -> DirectorySharingAttachments {
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
