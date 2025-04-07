import Foundation
import ArgumentParser
import Virtualization
import NIOPortForwarding
import System

public let defaultUbuntuImage = "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img"

private let cloudimage_help =
	"""

	The image could be one of local raw image, qcow2 cloud image, lxc simplestreams image, oci image
	The url image form are:
	  - local images (raw format): /Users/myhome/disk.img or file:///Users/myhome/disk.img
	  - cloud images (qcow2 format): https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img
	  - lxc images: images:ubuntu/noble/cloud, see remote command for detail
	If tart is installed, you can use tart images:
	  - secure oci images (tart format): ocis://ghcr.io/cirruslabs/ubuntu:latest (https)
	  - unsecure oci images (tart format): oci://unsecure.com/ubuntu:latest (http)

	"""

public let mount_help =
	"""

	Additional directory shares with an optional read-only and mount tag options (e.g. --mount=\"~/src/build:/opt/build\" or --mount=\"~/src/sources:/opt/sources,ro,name=Sources\")"
	The options are:
	  - ro: read-only
	  - name=name of the share
	  - uid=user id
	  - gid=group id

	"""

private let network_help =
	"""

	Add a network interface to the instance, where
	<spec> is in the \"key=value,key=value\" format,
	with the following keys available:
	name: the network to connect to (required), use
	the networks command for a list of possible values.
	 - mode: auto|manual (default: auto)
	 - mac: hardware address (default: random).
	You can also use a shortcut of \"<name>\" to mean \"name=<name>\".

	"""

private let socket_help =
	"""

	The socket option allows to create a virtio socket between the guest and the host. the port number to use for the connection must be greater than 1023.
	The mode is as follows:
	  - bind: creates a socket file on the host and listens for connections eg. bind://vsock:1234/tmp/unix_socket. The VM must listen the vsock port number.

	  - connect: uses an existing socket file on the host,
	    eg. connect://vsock:1234/tmp/unix_socket. The VM must connect on vsock port number.

	  - tcp: listen TCP on address. The VM must listen on the same port number,
	    eg. tcp://127.0.0.1:1234, tcp://[::1]:1234.

	  - udp: listen UDP on address. The VM must listen on the same port number,
	    eg. udp://127.0.0.1:1234, udp://[::1]:1234

	  - fd: use file descriptor. The VM must connect on the same port number,
	    eg. fd://24:1234, fd://24,25:1234. 24 = file descriptor for read or read/write if alone, 25 = file descriptor for write.
	    not supported with cakectl and with command build

	"""

private let console_help =
	"""

	  - --console=unix — use a Unix socket for the serial console located at ~/.tart/vms/<vm-name>/console.sock
	  - --console=unix:/tmp/serial.sock — use a Unix socket for the serial console located at the specified path
	  - --console=file — use a simple file for the serial console located at ~/.tart/vms/<vm-name>/console.log
	  - --console=fd://0,1 — use file descriptors for the serial console. The first file descriptor is for reading, the second is for writing
	    ** INFO: The console doesn't work on MacOS sonoma and earlier  **

	"""

import Security

extension Bundle {
	var isSandboxed: Bool {
		let defaultFlags: SecCSFlags = .init(rawValue: 0)
		var staticCode: SecStaticCode? = nil

		if SecStaticCodeCreateWithPath(self.bundleURL as CFURL, defaultFlags, &staticCode) == errSecSuccess {
			if SecStaticCodeCheckValidityWithErrors(staticCode!, SecCSFlags(rawValue: kSecCSBasicValidateOnly), nil, nil) == errSecSuccess {
				let requirementText = "entitlement[\"com.apple.security.app-sandbox\"] exists" as CFString
				var sandboxRequirement: SecRequirement?
				if SecRequirementCreateWithString(requirementText, defaultFlags, &sandboxRequirement) == errSecSuccess {
					if SecStaticCodeCheckValidityWithErrors(staticCode!, defaultFlags, sandboxRequirement, nil) == errSecSuccess {
						return true
					}
				}
			}
		}

		return false
	}
}

public struct Utils {
	public static let cakerSignature = "com.aldunelabs.caker"
	private static var homeDirectories: [Bool:URL] = [:]

	public static func isNestedVirtualizationSupported() -> Bool {
		if #available(macOS 15, *) {
			return VZGenericPlatformConfiguration.isNestedVirtualizationSupported
		}

		return false
	}

	public static func getHome(asSystem: Bool = false, createItIfNotExists: Bool = true) throws -> URL {
		guard let cakeHomeDir = homeDirectories[asSystem] else {
			let cakeHomeDir: URL

			if let customHome = ProcessInfo.processInfo.environment["CAKE_HOME"] {
				cakeHomeDir = URL(fileURLWithPath: customHome)
			} else if asSystem || geteuid() == 0 {
				let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .systemDomainMask, true)
				var applicationSupportDirectory = URL(fileURLWithPath: paths.first!, isDirectory: true)

				applicationSupportDirectory = URL(fileURLWithPath: cakerSignature,
				                                  isDirectory: true,
				                                  relativeTo: applicationSupportDirectory)
				cakeHomeDir = applicationSupportDirectory
			} else if Bundle.main.isSandboxed {
				cakeHomeDir = FileManager.default.homeDirectoryForCurrentUser
			} else {
				cakeHomeDir = FileManager.default
					.homeDirectoryForCurrentUser
					.appendingPathComponent(".cake", isDirectory: true)
			}

			if createItIfNotExists && FileManager.default.fileExists(atPath: cakeHomeDir.path) == false {
				try FileManager.default.createDirectory(at: cakeHomeDir, withIntermediateDirectories: true)
			}

			homeDirectories[asSystem] = cakeHomeDir

			return cakeHomeDir
		}


		return cakeHomeDir
	}

	public static func getDefaultServerAddress(asSystem: Bool) throws -> String {
		if let cakeListenAddress = ProcessInfo.processInfo.environment["CAKE_LISTEN_ADDRESS"] {
			return cakeListenAddress
		} else {
			var tartHomeDir = try Utils.getHome(asSystem: asSystem)

			tartHomeDir.append(path: ".caked.sock")

			return "unix://\(tartHomeDir.absoluteURL.path)"
		}
	}

	public static func getOutputLog(asSystem: Bool) -> String {
		if asSystem {
			return "/Library/Logs/caked.log"
		}

		return URL(fileURLWithPath: "caked.log", relativeTo: try? getHome(asSystem: false)).absoluteURL.path
	}

	public static func saveToTempFile(_ data: Data) throws -> String {
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString)
			.appendingPathExtension("txt")

		try data.write(to: url)

		return url.absoluteURL.path
	}

}

public enum CreatedNetworkMode: uint64, CaseIterable, ExpressibleByArgument, Codable, Sendable {
	public var defaultValueDescription: String { "shared" }

	public static let allValueStrings: [String] = CreatedNetworkMode.allCases.map { "\($0)" }

	case shared = 0
	case host = 1

	public init?(argument: String) {
		switch argument {
		case "host":
			self = .host
		case "shared":
			self = .shared
		default:
			return nil
		}
	}

	public var stringValue: String {
		switch self {
		case .host:
			return "host"
		case .shared:
			return "shared"
		}
	}
}

public struct NetworkCreateOptions: ParsableArguments, Sendable {
	@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
	public var name: String
	
	@Option(name: [.customLong("mode")], help: "vmnet mode")
	public var mode = CreatedNetworkMode.shared

	@Option(name: [.customLong("gateway")], help: ArgumentHelp("IP gateway", discussion: "first ip used for the configured shared network, e.g., \"192.168.105.1\"", valueName: "ip"))
	public var gateway: String = "192.168.105.1"
	
	@Option(name: [.customLong("dhcp-end")], help: ArgumentHelp("Last ip of the DHCP range, e.g., \"192.168.105.254\"", discussion: "requires --gateway to be specified", valueName: "ip"))
	public var dhcpEnd: String = "192.168.105.254"
	
	@Option(help: ArgumentHelp("DHCP lease timeout", valueName: "seconds"))
	public var dhcpLease: Int32 = 300

	@Option(name: [.customLong("netmask")], help: ArgumentHelp("Subnet mask", discussion: "requires --gateway to be specified"))
	public var subnetMask = "255.255.255.0"
	
	@Option(name: [.customLong("interface-id")], help: ArgumentHelp("VMNET interface ID", discussion: "randomly generated if not specified", valueName: "uuid"))
	public var interfaceID = UUID().uuidString
	
	@Option(name: [.customLong("nat66-prefix")], help: ArgumentHelp("The IPv6 prefix to use with shared mode", valueName: "prefix"))
	public var nat66Prefix: String? = nil
	
	public init() {
	}

}

public struct NetworkConfigureOptions: ParsableArguments, Sendable {
	@Argument(help: ArgumentHelp("Network name", discussion: "The name for network"))
	public var name: String
	
	@Option(name: [.customLong("gateway")], help: ArgumentHelp("IP gateway", discussion: "First ip used for the configured shared network, e.g., \"192.168.105.1\"", valueName: "ip"))
	public var gateway: String? = nil
	
	@Option(name: [.customLong("dhcp-end")], help: ArgumentHelp("Last ip of the DHCP range, e.g., \"192.168.105.254\"", discussion: "requires --gateway to be specified", valueName: "ip"))
	public var dhcpEnd: String? = nil
	
	@Option(help: ArgumentHelp("DHCP lease timeout", valueName: "seconds"))
	public var dhcpLease: Int32? = nil

	@Option(name: [.customLong("netmask")], help: ArgumentHelp("Subnet mask", discussion: "requires --gateway to be specified"))
	public var subnetMask: String? = nil
	
	@Option(name: [.customLong("interface-id")], help: ArgumentHelp("VMNET interface ID", discussion: "randomly generated if not specified", valueName: "uuid"))
	public var interfaceID: String? = nil
	
	@Option(name: [.customLong("nat66-prefix")], help: ArgumentHelp("The IPv6 prefix to use with shared mode", valueName: "prefix"))
	public var nat66Prefix: String? = nil
	
	public init() {
	}

}

public struct ConfigureOptions: ParsableArguments, Sendable {
	@Argument(help: "VM name")
	public var name: String

	@Option(name: [.customLong("cpus"), .customShort("c")], help: ArgumentHelp("Number of VM CPUs", valueName: "num"))
	public var cpu: UInt16? = nil

	@Option(name: [.long, .customShort("m")], help: ArgumentHelp("VM memory size in megabytes", valueName: "MB"))
	public var memory: UInt64? = nil

	@Option(name: [.customLong("disk-size"), .customShort("d")], help: ArgumentHelp("Disk size in GB", valueName: "GB"))
	public var diskSize: UInt16? = nil

	@Option(name: [.customLong("disk")], help: ArgumentHelp("Other attached disk", valueName: "path"))
	public var disks: [String] = ["unset"]

	@Option(name: [.long, .customShort("a")], help: ArgumentHelp("Tell if the VM must be start at boot"))
	public var autostart: Bool? = nil

	@Option(name: [.long, .customShort("t")], help: ArgumentHelp("Enable nested virtualization if possible"))
	public var nested: Bool?

	@Option(help: ArgumentHelp("Whether to automatically reconfigure the VM's display to fit the window"))
	public var displayRefit: Bool? = nil

	@Option(name: [.customLong("publish"), .customShort("p")], help: ArgumentHelp("Optional forwarded port for VM, syntax like docker", discussion: "value is like host:guest/(tcp|udp|both)", valueName: "value"))
	internal var published: [String] = ["unset"]

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Additional directory shares", discussion: mount_help, valueName: "[name:]path[:options]"))
	internal var mount: [String] = ["unset"]

	@Option(name: [.customLong("network"), .customShort("n")], help: ArgumentHelp("Add a network interface to the instance", discussion: network_help, valueName: "<spec>"))
	internal var network: [String] = ["unset"]

	@Flag(help: ArgumentHelp("Generate a new random MAC address for the VM."))
	public var randomMAC: Bool = false

	@Option(name: [.customLong("socket")], help: ArgumentHelp("Allow to create virtio socket between guest and host, format like url: <bind|connect|tcp|udp>://<address>:<port number>/<file for unix socket>, eg. bind://dummy:1234/tmp/vsock.sock", discussion: socket_help))
	internal var socket: [String] = ["unset"]

	@Option(name: [.customLong("console")], help: ArgumentHelp("URL to the serial console (e.g. --console=unix, --console=file, or --console=\"fd://0,1\" or --console=\"unix:/tmp/serial.sock\")", discussion: console_help,  valueName: "url"))
	public var console: String?

	public init(request: Caked_ConfigureRequest) {
		self.name = self.name
		self.displayRefit = false

		if request.hasCpu {
			self.cpu = UInt16(request.cpu)
		} else {
			self.cpu = nil
		}

		if request.hasMemory {
			self.memory = UInt64(request.memory)
		} else {
			self.memory = nil
		}

		if request.hasDiskSize {
			self.diskSize = UInt16(request.diskSize)
		} else {
			self.diskSize = nil
		}

		if request.hasNested {
			self.nested = request.nested
		} else {
			self.nested = nil
		}

		if request.hasAutostart {
			self.autostart = request.autostart
		} else {
			self.autostart = nil
		}

		if request.hasAttachedDisks {
			self.disks = request.attachedDisks.components(separatedBy: ",")
		} else {
			self.disks = ["unset"]
		}

		if request.hasMounts {
			self.mount = request.mounts.components(separatedBy: ",")
		} else {
			self.mount = ["unset"]
		}

		if request.hasNetworks {
			self.network = request.networks.components(separatedBy: ",")
		} else {
			self.network = ["unset"]
		}

		if request.hasRandomMac {
			self.randomMAC = request.randomMac
		}

		if request.hasForwardedPort {
			self.published = request.forwardedPort.components(separatedBy: ",")
		} else {
			self.published = ["unset"]
		}

		if request.hasSockets {
			self.socket = request.sockets.components(separatedBy: ",")
		} else {
			self.socket = []
		}

		if request.hasConsole {
			self.console = request.console
		}
	}

	public var consoleURL: ConsoleAttachment? {
		get {
			if let console = self.console {
				return ConsoleAttachment(argument: console)
			}

			return nil
		}
	}

	public var attachedDisks: [DiskAttachement]? {
		get {
			if disks.contains("unset") {
				return nil
			}

			return disks.compactMap {
				DiskAttachement(argument: $0)
			}
		}
	}

	public var forwardedPort: [ForwardedPort]? {
		get {
			if published.contains("unset") {
				return nil
			}

			return published.compactMap {
				ForwardedPort(argument: $0)
			}
		}
	}

	public var sockets: [SocketDevice]? {
		get {
			if socket.contains("unset") {
				return nil
			}

			return socket.compactMap { SocketDevice(argument: $0) }
		}
	}

	public var mounts: [DirectorySharingAttachment]? {
		get {
			if mount.contains("unset") {
				return nil
			}

			return mount.compactMap { DirectorySharingAttachment(argument: $0)
			}
		}
	}

	public var networks: [BridgeAttachement]? {
		get {
			if network.contains("unset") {
				return nil
			}

			return network.compactMap { BridgeAttachement(argument: $0) }
		}
	}

	mutating public func setMount(value: [String] = []) {
		mount = value
	}

	mutating public func setNetwork(value: [String] = []) {
		network = value
	}

	mutating public func setPublished(value: [String] = []) {
		published = value
	}

	mutating public func setSocket(value: [String] = []) {
		socket = value
	}

	public init() {
	}
}

public struct BuildOptions: ParsableArguments {
	@Argument(help: "VM name")
	public var name: String

	@Option(name: [.customLong("cpus"), .customShort("c")], help: ArgumentHelp("Number of VM CPUs", valueName: "num"))
	public var cpu: UInt16 = 1

	@Option(name: [.long, .customShort("m")], help: ArgumentHelp("VM memory size in megabytes", valueName: "MB"))
	public var memory: UInt64 = 512

	@Option(name: [.customLong("disk-size"), .customShort("d")], help: ArgumentHelp("Disk size in GB", valueName: "GB"))
	public var diskSize: UInt16 = 10

	@Option(name: [.customLong("disk")], help: ArgumentHelp("Other attached disk", valueName: "path"))
	public var attachedDisks: [DiskAttachement] = []

	@Option(name: [.long, .customShort("u")], help: "The user to use for the VM")
	public var user: String = "admin"

	@Option(name: [.long, .customShort("w")], help: "The user password for login, none by default")
	public var password: String?

	@Option(name: [.long, .customShort("g")], help: "The main existing group for the user")
	public var mainGroup: String = "admin"

	@Flag(name: [.long, .customShort("k")], help: ArgumentHelp("Tell if the user admin allow password for ssh"))
	public var clearPassword: Bool = false

	@Flag(name: [.long, .customShort("a")], help: ArgumentHelp("Tell if the VM must be start at boot"))
	public var autostart: Bool = false

	@Flag(name: [.long, .customShort("t")], help: ArgumentHelp("Enable nested virtualization if possible"))
	public var nested: Bool = false

	@Argument(help: ArgumentHelp("create a linux VM using a cloud image", discussion: cloudimage_help, valueName: "url"))
	public var image: String = defaultUbuntuImage

	@Option(name: [.long, .customShort("i")], help: ArgumentHelp("Optional ssh-authorized-key file path for linux VM", valueName: "path"))
	public var sshAuthorizedKey: String?

	//@Option(help: ArgumentHelp("Optional cloud-init vendor-data file path for linux VM", valueName: "path"))
	@Option(help: .hidden)
	public var vendorData: String?

	@Option(name: [.customLong("cloud-init")], help: ArgumentHelp("Optional cloud-init user-data file path for linux VM", discussion: "Path or URL to a user-data cloud-init configuration, or '-' for stdin", valueName: "path"))
	public var userData: String?

	@Option(help: ArgumentHelp("Optional cloud-init network-config file path for linux VM", valueName: "path"))
	public var networkConfig: String?

	@Flag(help: ArgumentHelp("Whether to automatically reconfigure the VM's display to fit the window"))
	public var displayRefit: Bool = false

	@Option(name: [.customLong("publish"), .customShort("p")], help: ArgumentHelp("Optional forwarded port for VM, syntax like docker", discussion: "value is like host:guest/(tcp|udp|both)", valueName: "value"))
	public var forwardedPorts: [ForwardedPort] = []

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Additional directory shares", discussion: mount_help))
	public var mounts: [DirectorySharingAttachment] = []

	@Option(name: [.customLong("network"), .customShort("n")], help: ArgumentHelp("Add a network interface to the instance", discussion: network_help , valueName: "spec"))
	public var networks: [BridgeAttachement] = []

	@Option(name: [.customLong("socket")], help: ArgumentHelp("Allow to create virtio socket between guest and host, format like url: <bind|connect|tcp|udp>://<address>:<port number>/<file for unix socket>, eg. bind://dummy:1234/tmp/vsock.sock", discussion: socket_help))
	public var sockets: [SocketDevice] = []

	@Option(name: [.customLong("console")], help: ArgumentHelp("URL to the serial console (e.g. --console=unix, --console=file, or --console=\"fd://0,1\" or --console=\"unix:/tmp/serial.sock\")", discussion: console_help, valueName: "url"))
	public var consoleURL: ConsoleAttachment?

	public init() {
	}

	public init(name: String, cpu: UInt16 = 2, memory: UInt64 = 2048, diskSize: UInt16 = 10,
	            attachedDisks: [DiskAttachement] = [],
	            user: String = "admin",
	            password: String? = "nil",
	            mainGroup: String = "admin",
	            clearPassword: Bool = false,
	            autostart: Bool = true,
	            nested: Bool = true,
	            image: String = defaultUbuntuImage,
	            sshAuthorizedKey: String? = nil,
	            vendorData: String? = nil,
	            userData: String? = nil,
	            networkConfig: String? = nil,
	            displayRefit: Bool = true,
	            forwardedPorts: [ForwardedPort] = [],
	            mounts: [DirectorySharingAttachment] = ["~"].compactMap { DirectorySharingAttachment(argument: $0)},
	            networks: [BridgeAttachement] = [],
	            sockets: [SocketDevice]	= [],
	            consoleURL: ConsoleAttachment? = nil) {
		self.name = name
		self.cpu = cpu
		self.memory = memory
		self.diskSize = diskSize
		self.attachedDisks = attachedDisks
		self.user = user
		self.password = password
		self.mainGroup = mainGroup
		self.clearPassword = clearPassword
		self.autostart = autostart
		self.nested = nested
		self.image = image
		self.sshAuthorizedKey = sshAuthorizedKey
		self.vendorData = vendorData
		self.userData = userData
		self.networkConfig = networkConfig
		self.displayRefit = displayRefit
		self.forwardedPorts = forwardedPorts
		self.mounts = mounts
		self.networks = networks
		self.sockets = sockets
		self.consoleURL = consoleURL
	}

	public init(request: Caked_CommonBuildRequest) throws {
		self.name = request.name
		self.displayRefit = false

		if request.hasCpu {
			self.cpu = UInt16(request.cpu)
		} else {
			self.cpu = 1
		}

		if request.hasMemory {
			self.memory = UInt64(request.memory)
		} else {
			self.memory = 512
		}

		if request.hasDiskSize {
			self.diskSize = UInt16(request.diskSize)
		} else {
			self.diskSize = 20
		}

		if request.hasAttachedDisks {
			self.attachedDisks = try request.attachedDisks.components(separatedBy: ",").compactMap {
				try DiskAttachement(parseFrom: $0)
			}
		} else {
			self.attachedDisks = []
		}

		if request.hasUser {
			self.user = request.user
		} else {
			self.user = "admin"
		}

		if request.hasPassword {
			self.password = request.password
		} else {
			self.password = nil
		}

		if request.hasMainGroup {
			self.mainGroup = request.mainGroup
		} else {
			self.mainGroup = "admin"
		}

		if request.hasSshPwAuth {
			self.clearPassword = request.sshPwAuth
		} else {
			self.clearPassword = false
		}

		if request.hasNested {
			self.nested = request.nested
		} else {
			self.nested = true
		}

		if request.hasAutostart {
			self.autostart = request.autostart
		} else {
			self.autostart = false
		}

		if request.hasImage && request.image.isEmpty == false {
			self.image = request.image
		} else {
			self.image = defaultUbuntuImage
		}

		if request.hasSshAuthorizedKey && request.sshAuthorizedKey.isEmpty == false {
			self.sshAuthorizedKey = try Utils.saveToTempFile(request.sshAuthorizedKey)
		} else {
			self.sshAuthorizedKey = nil
		}

		if request.hasUserData && request.userData.isEmpty == false {
			self.userData = try Utils.saveToTempFile(request.userData)
		} else {
			self.userData = nil
		}

		if request.hasVendorData && request.vendorData.isEmpty == false {
			self.vendorData = try Utils.saveToTempFile(request.vendorData)
		} else {
			self.vendorData = nil
		}

		if request.hasNetworkConfig && request.networkConfig.isEmpty == false {
			self.networkConfig = try Utils.saveToTempFile(request.networkConfig)
		} else {
			self.networkConfig = nil
		}

		if request.hasForwardedPort && request.forwardedPort.isEmpty == false {
			self.forwardedPorts = request.forwardedPort.components(separatedBy: ",").compactMap { argument in
				return ForwardedPort(argument: argument)
			}
		} else {
			self.forwardedPorts = []
		}

		if request.hasMounts && request.mounts.isEmpty == false {
			self.mounts = try request.mounts.components(separatedBy: ",").compactMap {
				try DirectorySharingAttachment(parseFrom: $0)
			}
		} else {
			self.mounts = []
		}

		if request.hasNetworks && request.networks.isEmpty == false {
			self.networks = try request.networks.components(separatedBy: ",").compactMap {
				try BridgeAttachement(parseFrom: $0) }
		} else {
			self.networks = []
		}

		if request.hasSockets && request.sockets.isEmpty == false {
			self.sockets = try request.sockets.components(separatedBy: ",").compactMap {
				try SocketDevice(parseFrom: $0)
			}
		} else {
			self.sockets = []
		}

		if request.hasConsole && request.console.isEmpty == false {
			self.consoleURL = ConsoleAttachment(argument: request.console)
		} else {
			self.consoleURL = nil
		}
	}

	mutating public func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		if nested && Utils.isNestedVirtualizationSupported() == false {
			self.nested = false
		}
	}
}

public struct ClientCertificatesLocation: Codable {
	public let caCertURL: URL
	public let clientKeyURL: URL
	public let clientCertURL: URL

	init(certHome: URL) {
		self.caCertURL = URL(fileURLWithPath: "ca.pem", relativeTo: certHome).absoluteURL
		self.clientKeyURL = URL(fileURLWithPath: "client.key", relativeTo: certHome).absoluteURL
		self.clientCertURL = URL(fileURLWithPath: "client.pem", relativeTo: certHome).absoluteURL
	}

	public static func getCertificats(asSystem: Bool) throws -> ClientCertificatesLocation {
		return ClientCertificatesLocation(certHome: URL(fileURLWithPath: "certs", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem)))
	}

	public func exists() -> Bool {
		return FileManager.default.fileExists(atPath: self.clientKeyURL.path) && FileManager.default.fileExists(atPath: self.clientCertURL.path)
	}
}

public struct ShortInfoReply: Sendable, Codable {
	public let name: String
	public let ipaddresses: String
	public let cpuCount: String
	public let memory: String

	public init(name: String, ipaddresses: [String], cpuCount: Int32, memory: UInt64) {
		self.name = name
		self.ipaddresses = ipaddresses.joined(separator: ", ")
		self.cpuCount = "\(cpuCount)"
		self.memory = ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory)
	}

	public init(ipaddress: String) {
		self.name = ""
		self.ipaddresses = ipaddress
		self.cpuCount = ""
		self.memory = ""
	}
}

public extension String {
	var expandingTildeInPath: String {
		if self.hasPrefix("~") {
			return NSString(string: self).expandingTildeInPath
		}

		return self
	}

	init(errno: Errno) {
		self = String(cString: strerror(errno.rawValue))
	}

	init(errno: Int32) {
		self = String(cString: strerror(errno))
	}

	func stringBeforeLast(before: Character) -> String {
		if let r = self.lastIndex(of: before) {
			return String(self[self.startIndex..<r])
		} else {
			return self
		}
	}

	func stringBefore(before: String) -> String {
		if let r = self.range(of: before) {
			return String(self[self.startIndex..<r.lowerBound])
		} else {
			return self
		}
	}

	func stringAfter(after: String) -> String {
		if let r = self.range(of: after) {
			return String(self[r.upperBound..<self.endIndex])
		} else {
			return self
		}
	}

	func substring(_ bounds: PartialRangeUpTo<Int>) -> String {
		let endIndex = self.index(self.startIndex, offsetBy: bounds.upperBound)

		return String(self[self.startIndex..<endIndex])
	}

	func substring(_ bounds: Range<Int>) -> String {
		let startIndex = self.index(self.startIndex, offsetBy: bounds.lowerBound)
		let endIndex = self.index(self.startIndex, offsetBy: bounds.upperBound)

		return String(self[startIndex..<endIndex])
	}

}

