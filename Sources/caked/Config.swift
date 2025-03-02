import Foundation
import Virtualization
import GRPCLib
import NIOPortForwarding

typealias DisplaySize = Dictionary<String, Int>

extension DisplaySize {
	var width: Int {
		set { self["width"] = newValue }
		get { self["width"]! }
	}

	var height: Int {
		set { self["height"] = newValue }
		get { self["height"]! }
	}
}

enum ConfigFileName: String {
	case config = "config.json"
	case cake = "cake.json"
}

enum VirtualizedOS: String, Codable {
	case darwin
	case linux
}

final class CakeConfig{
	var config: Config
	var cake: Config
	let location: URL

	internal final class Config {
		var data: Dictionary<String, Any>
		var dirty: Bool

		init() {
			self.dirty = false
			self.data = Dictionary<String, Any>()
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


	var version: Int {
		set { self.config["version"] = newValue }
		get { self.config["version"] as! Int }
	}

	var os: VirtualizedOS {
		set { self.config["os"] = newValue.rawValue }
		get {
			let os: String? = self.config["os"] as? String

			if let os = os {
				return VirtualizedOS(rawValue: os)!
			}

			return .linux
		}
	}

	var arch: Architecture {
		set { self.config["arch"] = newValue.rawValue }
		get {
			let arch: String? = self.config["arch"] as? String

			if let arch = arch {
				return Architecture(rawValue: arch)
			}

			return Architecture.current()
		}
	}

	var cpuCountMin: Int {
		set { self.config["cpuCountMin"] = newValue }
		get { self.config["cpuCountMin"] as! Int }
	}


	#if arch(arm64)
		var ecid: VZMacMachineIdentifier {
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

		var hardwareModel: VZMacHardwareModel? {
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

	var cpuCount: Int {
		set { self.config["cpuCount"] = newValue }
		get { self.config["cpuCount"] as! Int }
	}

	var memorySizeMin: UInt64 {
		set { self.config["memorySizeMin"] = newValue }
		get { self.config["memorySizeMin"] as! UInt64 }
	}

	var memorySize: UInt64 {
		set { self.config["memorySize"] = newValue }
		get { self.config["memorySize"] as! UInt64 }
	}

	var macAddress: VZMACAddress? {
		set { if let value = newValue { self.config["macAddress"] = value.string } else { self.config["macAddress"] = nil } }
		get { if let addr = self.config["macAddress"] as? String {
			return VZMACAddress(string: addr)
		}

		return nil
		}
	}

	var displayRefit: Bool {
		set { self.config["displayRefit"] = newValue }
		get { self.config["displayRefit"] as? Bool ?? false}
	}

	var configuredUser: String {
		set { self.cake["configuredUser"] = newValue }
		get { self.cake["configuredUser"] as? String ?? "admin" }
	}

	var configuredPassword: String? {
		set { self.cake["configuredPassword"] = newValue }
		get { self.cake["configuredPassword"] as? String }
	}

	var autostart: Bool {
		set { self.cake["autostart"] = newValue }
		get { self.cake["autostart"] as? Bool ?? false }
	}

	var agent: Bool {
		set { self.cake["agent"] = newValue }
		get { self.cake["agent"] as? Bool ?? false }
	}

	var firstLaunch: Bool {
		set { self.cake["firstLaunch"] = newValue }
		get { self.cake["firstLaunch"] as? Bool ?? true }
	}

	var nested: Bool {
		set { self.cake["nested"] = newValue }
		get { self.cake["nested"] as? Bool ?? false }
	}

	var disks: [DiskAttachement] {
		set { self.cake["disks"] = newValue.map{$0.description} }
		get {
			guard let mounts:[String] = self.cake["disks"] as? [String] else {
				return []
			}

			return mounts.compactMap { DiskAttachement(argument: $0) }
		}
	}

	var mounts: [DirectorySharingAttachment] {
		set { self.cake["mounts"] = newValue.map{$0.description} }
		get {
			guard let mounts:[String] = self.cake["mounts"] as? [String] else {
				return []
			}

			return mounts.compactMap { DirectorySharingAttachment(argument: $0) }
		}
	}

	var networks: [BridgeAttachement] {
		set { self.cake["networks"] = newValue.map{$0.description} }
		get {
			guard let mounts:[String] = self.cake["networks"] as? [String] else {
				return []
			}

			return mounts.compactMap { BridgeAttachement(argument: $0) }
		}
	}

	var useCloudInit: Bool {
		set { self.cake["cloud-init"] = newValue }
		get { self.cake["cloud-init"] as? Bool ?? false}
	}

	var sockets: [SocketDevice] {
		set { self.cake["sockets"] = newValue.map{$0.description} }
		get {
			guard let mounts:[String] = self.cake["sockets"] as? [String] else {
				return []
			}

			return mounts.compactMap { SocketDevice(argument: $0) }
		}
	}

	var console: ConsoleAttachment? {
		set { self.cake["console"] = newValue?.description }
		get { guard let consoleURL: String = self.cake["console"] as? String else {
			return nil
		}

		return ConsoleAttachment(argument: consoleURL)
		}
	}

	var forwardedPorts: [ForwardedPort] {
		set { self.cake["forwardedPorts"] = newValue.map{$0.description} }
		get {
			guard let mounts:[String] = self.cake["forwardedPorts"] as? [String] else {
				return []
			}

			return mounts.compactMap { ForwardedPort(argument: $0) }
		}
	}

	var runningIP: String? {
		set { self.cake["runningIP"] = newValue }
		get { self.cake["runningIP"] as? String ?? nil }
	}

	var nestedVirtualization: Bool {
		get {
			if self.os == .linux && Utils.isNestedVirtualizationSupported() {
				return self.nested
			}

			return false
		}
	}

	var display: DisplaySize {
		set { self.config["display"] = newValue }
		get { self.config["display"] as! DisplaySize }
	}

	init(location: URL,
	     os: VirtualizedOS,
	     autostart: Bool,
	     configuredUser: String,
	     configuredPassword: String?,
	     displayRefit: Bool,
	     cpuCountMin: Int,
	     memorySizeMin: UInt64,
	     macAddress: VZMACAddress = VZMACAddress.randomLocallyAdministered()) {

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
	}

	init(location: URL) throws {
		self.location = location
		self.config = try Config(contentsOf: self.location.appendingPathComponent(ConfigFileName.config.rawValue))
		self.cake = try Config(contentsOf: self.location.appendingPathComponent(ConfigFileName.cake.rawValue))
	}

	init(location: URL, options: BuildOptions) throws {
		self.location = location
		self.config = try Config(contentsOf: self.location.appendingPathComponent(ConfigFileName.config.rawValue))
		self.cake = Config()

		self.configuredUser = options.user
		self.configuredPassword = options.password
		self.autostart = options.autostart
		self.displayRefit = options.displayRefit
		self.configuredPassword = configuredPassword
		self.autostart = autostart
		self.useCloudInit = false
		self.agent = false

		if self.os == .darwin {
			self.cpuCount = max(Int(options.cpu), self.cpuCountMin)
			self.memorySize = max(options.memory * 1024 * 1024, UInt64(self.memorySizeMin))
		} else {
			self.cpuCount = Int(options.cpu)
			self.memorySize = options.memory * 1024 * 1024
			self.nested = options.nested
		}
	}

	func save() throws {
		try self.config.save(to: self.location.appendingPathComponent(ConfigFileName.config.rawValue))
		try self.cake.save(to: self.location.appendingPathComponent(ConfigFileName.cake.rawValue))
	}

	func resetMacAddress() {
		self.macAddress = VZMACAddress.randomLocallyAdministered()
	}

	func platform(nvramURL: URL, needsNestedVirtualization: Bool) throws -> GuestPlateForm {
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
	func collectNetworks() throws -> [NetworkAttachement] {
		if networks.isEmpty {
			if let macAddress = self.macAddress {
				return [SharedNetworkInterface(macAddress: macAddress)]
			}

			return [SharedNetworkInterface(macAddress: VZMACAddress.randomLocallyAdministered())]
		}

		return networks.compactMap { inf in
			if inf.network == "nat" || inf.network == "NAT shared network" {
				if let macAddress = self.macAddress {
					return SharedNetworkInterface(macAddress: macAddress)
				}

				return SharedNetworkInterface(macAddress: VZMACAddress.randomLocallyAdministered())
			}

			let foundInterface = VZBridgedNetworkInterface.networkInterfaces.first {
				$0.identifier == inf.network || $0.localizedDisplayName == inf.network
			}

			if let interface = foundInterface {
				if let macAddress = inf.macAddress, let mac = VZMACAddress(string: macAddress) {
					return BridgedNetworkInterface(interface: interface, macAddress: mac)
				}

				return BridgedNetworkInterface(interface: interface, macAddress: VZMACAddress.randomLocallyAdministered())	
			}

			Logger.warn("Network interface \(inf.network) not found")

			return nil
		}
	}

	func additionalDiskAttachments() throws -> [VZStorageDeviceConfiguration] {
		let cloudInit = URL(fileURLWithPath: "cloud-init.iso", relativeTo: self.location).absoluteURL
		var attachedDisks: [VZStorageDeviceConfiguration] = []

		attachedDisks.append(contentsOf: self.disks.compactMap { try? $0.configuration() })

		if try cloudInit.exists() {
			let attachment = try VZDiskImageStorageDeviceAttachment(url: cloudInit, readOnly: true, cachingMode: .cached, synchronizationMode: VZDiskImageSynchronizationMode.none)

			let cdrom = VZVirtioBlockDeviceConfiguration(attachment: attachment)

			cdrom.blockDeviceIdentifier = "CIDATA"

			attachedDisks.append(cdrom)
		}

		return attachedDisks
	}

	func directorySharingAttachments() throws -> [VZDirectorySharingDeviceConfiguration] {
		if self.mounts.isEmpty {
			return []
		}

		if self.os == .darwin {
			let sharingDevice = VZVirtioFileSystemDeviceConfiguration(tag: VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag)
			var directories: [String : VZSharedDirectory] = [:]

			self.mounts.forEach {
				if let config = $0.configuration {
					directories[$0.human] = config
				}
			}

			sharingDevice.share = VZMultipleDirectoryShare(directories: directories)

			return [sharingDevice]
		}

		return self.mounts.reduce(into: [VZDirectorySharingDeviceConfiguration]()) { configurations, mount in
			let sharingDevice = VZVirtioFileSystemDeviceConfiguration(tag: mount.name)

			sharingDevice.share = VZSingleDirectoryShare(directory: .init(url: mount.path, readOnly: mount.readOnly))
		}
	}

	func socketDeviceAttachments() throws -> [SocketDevice] {
		let vsock = URL(fileURLWithPath: "agent.sock", relativeTo: self.location).absoluteURL.path()
		var sockets: [SocketDevice] = [SocketDevice(mode: SocketMode.bind, port: 5000, bind: vsock)]

		if FileManager.default.fileExists(atPath: vsock) {
			try FileManager.default.removeItem(atPath: vsock)
		}

		sockets.append(contentsOf: self.sockets)

		return sockets
	}

	func consoleAttachment() throws -> URL? {
		if let console = self.console {
			return try console.consoleURL(vmDir: self.location)
		}

		return nil
	}
}
