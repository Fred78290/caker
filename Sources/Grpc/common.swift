import Foundation
import ArgumentParser
import Virtualization
import NIOPortForwarding

public struct Utils {
	public static let cakerSignature = "com.aldunelabs.caker"

	public static func isNestedVirtualizationSupported() -> Bool {
		if #available(macOS 15, *) {
			return VZGenericPlatformConfiguration.isNestedVirtualizationSupported
		}

		return false
	}

	public static func getHome(asSystem: Bool = false) throws -> URL {
		let cakeHomeDir: URL

		if asSystem {
			let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .systemDomainMask, true)
			var applicationSupportDirectory = URL(fileURLWithPath: paths.first!, isDirectory: true)

			applicationSupportDirectory = URL(fileURLWithPath: cakerSignature,
			                                  isDirectory: true,
			                                  relativeTo: applicationSupportDirectory)
			try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)

			cakeHomeDir = applicationSupportDirectory
		} else if let customHome = ProcessInfo.processInfo.environment["CAKE_HOME"] {
			cakeHomeDir = URL(fileURLWithPath: customHome)
		} else {
			cakeHomeDir = FileManager.default
				.homeDirectoryForCurrentUser
				.appendingPathComponent(".cake", isDirectory: true)
		}

		try FileManager.default.createDirectory(at: cakeHomeDir, withIntermediateDirectories: true)

		return cakeHomeDir
	}

	public static func getDefaultServerAddress(asSystem: Bool) throws -> String {
		if let cakeListenAddress = ProcessInfo.processInfo.environment["CAKE_LISTEN_ADDRESS"] {
			return cakeListenAddress
		} else {
			var tartHomeDir = try Utils.getHome(asSystem: asSystem)

			tartHomeDir.append(path: ".caked.sock")

			return "unix://\(tartHomeDir.absoluteURL.path())"
		}
	}

	public static func getOutputLog(asSystem: Bool) -> String {
		if asSystem {
			return "/Library/Logs/caked.log"
		}

		return URL(fileURLWithPath: "caked.log", relativeTo: try? getHome(asSystem: false)).absoluteURL.path()
	}

}

public struct ConfigureOptions: ParsableArguments {
	@Argument(help: "VM name")
	public var name: String

	@Option(name: [.long, .customShort("c")], help: "Number of VM CPUs")
	public var cpu: UInt16? = nil

	@Option(name: [.long, .customShort("m")], help: "VM memory size in megabytes")
	public var memory: UInt64? = nil

	@Option(name: [.long, .customShort("d")], help: ArgumentHelp("Disk size in GB"))
	public var diskSize: UInt16? = nil

	@Option(name: [.long, .customShort("a")], help: ArgumentHelp("Tell if the VM must be start at boot"))
	public var autostart: Bool? = nil

	@Option(name: [.long, .customShort("t")], help: ArgumentHelp("Enable nested virtualization if possible"))
	public var nested: Bool?

	@Option(help: ArgumentHelp("Whether to automatically reconfigure the VM's display to fit the window"))
	public var displayRefit: Bool? = nil

	@Option(name: [.customLong("publish"), .customShort("p")], help: ArgumentHelp("Optional forwarded port for VM, syntax like docker", valueName: "host:guest/(tcp|udp|both)"))
	internal var published: [String] = ["unset"]

	@Option(name: [.customLong("mount"), .customShort("v")],
	        help: ArgumentHelp("Additional directory shares",
	                           discussion: "Additional directory shares with an optional read-only and mount tag options (e.g. --mount=\"~/src/build\" or --mount=\"~/src/sources:ro\")", valueName: "[name:]path[:options]"))
	internal var mount: [String] = ["unset"]

	@Option(help: ArgumentHelp("Add a network interface to the instance",
	                           discussion: """
	                           Add a network interface to the instance, where
	                           <spec> is in the \"key=value,key=value\" format,
	                           with the following keys available:
	                           name: the network to connect to (required), use
	                           the networks command for a list of possible
	                           values.
	                           mode: auto|manual (default: auto)
	                           mac: hardware address (default: random).
	                           You can also use a shortcut of \"<name>\" to mean
	                           \"name=<name>\".
	                           """	, valueName: "<spec>"))
	internal var network: [String] = ["unset"]

	@Flag(help: ArgumentHelp("Generate a new random MAC address for the VM."))
	public var randomMAC: Bool = false

	@Option(name: [.customLong("socket")],
	        help: ArgumentHelp("Allow to create virtio socket between guest and host, format like url: <bind|connect|tcp|udp>://<address>:<port number>/<file for unix socket>, eg. bind://dummy:1234/tmp/vsock.sock",
	                           discussion: """
	                           The vsock option allows to create a virtio socket between the guest and the host. the port number to use for the connection must be greater than 1023.
	                           The mode is as follows:
	                           - bind: creates a socket file on the host and listens for connections eg. bind://vsock:1234/tmp/unix_socket. The VM must listen the vsock port number.
	                           - connect: uses an existing socket file on the host, eg. connect://vsock:1234/tmp/unix_socket. The VM must connect on vsock port number.
	                           - tcp: listen TCP on address. The VM must listen on the same port number, eg. tcp://127.0.0.1:1234, tcp://[::1]:1234.
	                           - udp: listen UDP on address. The VM must listen on the same port number,  eg. udp://127.0.0.1:1234, udp://[::1]:1234
	                           - fd: use file descriptor. The VM must connect on the same port number,  eg. fd://24:1234, fd://24,25:1234. 24 = file descriptor for read or read/write if alone, 25 = file descriptor for write.
	                           """))
	internal var socket: [String] = ["unset"]

	@Option(name: [.customLong("console")],
	        help: ArgumentHelp("URL to the serial console (e.g. --console=unix, --console=file, or --console=\"fd://0,1\" or --console=\"unix:/tmp/serial.sock\")",
	                           discussion: """
	                           - --console=unix — use a Unix socket for the serial console located at ~/.tart/vms/<vm-name>/console.sock
	                           - --console=unix:/tmp/serial.sock — use a Unix socket for the serial console located at the specified path
	                           - --console=file — use a simple file for the serial console located at ~/.tart/vms/<vm-name>/console.log
	                           - --console=fd://0,1 — use file descriptors for the serial console. The first file descriptor is for reading, the second is for writing
	                           ** INFO: The console doesn't work on MacOS sonoma and earlier  **
	                           """,
	                           valueName: "url"))
	public var console: String?

	public var consoleURL: ConsoleAttachment? {
		get {
			if let console = self.console {
				return ConsoleAttachment(argument: console)
			}

			return nil
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

	public init() {
	}
}

public struct BuildOptions: ParsableArguments {
	@Option(name: [.long, .customShort("n")], help: "VM name")
	public var name: String

	@Option(name: [.long, .customShort("c")], help: "Number of VM CPUs")
	public var cpu: UInt16 = 1

	@Option(name: [.long, .customShort("m")], help: "VM memory size in megabytes")
	public var memory: UInt64 = 512

	@Option(name: [.long, .customShort("d")], help: ArgumentHelp("Disk size in GB"))
	public var diskSize: UInt16 = 10

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

	@Argument(help: ArgumentHelp("create a linux VM using a cloud image", discussion:"""
	The image could be one of local raw image, qcow2 cloud image, lxc simplestreams image, oci image
	The url image form are:
	- local images: /Users/myhome/disk.img or file:///Users/myhome/disk.img
	- cloud images: https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img
	- lxc images: images:ubuntu/noble/cloud, see remote command for detail
	- secure oci images: ocis://ghcr.io/cirruslabs/ubuntu:latest (https)
	- unsecure oci images: oci://unsecure.com/ubuntu:latest (http)
	""", valueName: "url"))
	public var image: String = "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img"

	@Option(name: [.long, .customShort("i")], help: ArgumentHelp("Optional ssh-authorized-key file path for linux VM", valueName: "path"))
	public var sshAuthorizedKey: String?

	@Option(help: ArgumentHelp("Optional cloud-init vendor-data file path for linux VM", valueName: "path"))
	public var vendorData: String?

	@Option(name: [.long, .customLong("cloud-init")], help: ArgumentHelp("Optional cloud-init user-data file path for linux VM", valueName: "Path or URL to a user-data cloud-init configuration, or '-' for stdin"))
	public var userData: String?

	@Option(help: ArgumentHelp("Optional cloud-init network-config file path for linux VM", valueName: "path"))
	public var networkConfig: String?

	@Flag(help: ArgumentHelp("Whether to automatically reconfigure the VM's display to fit the window"))
	public var displayRefit: Bool = false

	@Option(name: [.customLong("publish"), .customShort("p")], help: ArgumentHelp("Optional forwarded port for VM, syntax like docker", valueName: "host:guest/(tcp|udp|both)"))
	internal var published: [String] = []

	@Option(name: [.customLong("mount"), .customShort("v")],
	        help: ArgumentHelp("Additional directory shares",
	                           discussion: "Additional directory shares with an optional read-only and mount tag options (e.g. --mount=\"~/src/build\" or --mount=\"~/src/sources:ro\")", valueName: "[name:]path[:options]"))
	internal var shares: [String] = []

	@Option(help: ArgumentHelp("Add a network interface to the instance",
	                           discussion: """
	                           Add a network interface to the instance, where
	                           <spec> is in the \"key=value,key=value\" format,
	                           with the following keys available:
	                           name: the network to connect to (required), use
	                           the networks command for a list of possible
	                           values.
	                           mode: auto|manual (default: auto)
	                           mac: hardware address (default: random).
	                           You can also use a shortcut of \"<name>\" to mean
	                           \"name=<name>\".
	                           """	, valueName: "<spec>"))
	internal var bridged: [String] = []

	@Option(name: [.customLong("socket")],
	        help: ArgumentHelp("Allow to create virtio socket between guest and host, format like url: <bind|connect|tcp|udp>://<address>:<port number>/<file for unix socket>, eg. bind://dummy:1234/tmp/vsock.sock",
	                           discussion: """
	                           The vsock option allows to create a virtio socket between the guest and the host. the port number to use for the connection must be greater than 1023.
	                           The mode is as follows:
	                           - bind: creates a socket file on the host and listens for connections eg. bind://vsock:1234/tmp/unix_socket. The VM must listen the vsock port number.
	                           - connect: uses an existing socket file on the host, eg. connect://vsock:1234/tmp/unix_socket. The VM must connect on vsock port number.
	                           - tcp: listen TCP on address. The VM must listen on the same port number, eg. tcp://127.0.0.1:1234, tcp://[::1]:1234.
	                           - udp: listen UDP on address. The VM must listen on the same port number,  eg. udp://127.0.0.1:1234, udp://[::1]:1234
	                           - fd: use file descriptor. The VM must connect on the same port number,  eg. fd://24:1234, fd://24,25:1234. 24 = file descriptor for read or read/write if alone, 25 = file descriptor for write.
	                           """))
	public var vsock: [String] = []

	@Option(name: [.customLong("console")],
	        help: ArgumentHelp("URL to the serial console (e.g. --console=unix, --console=file, or --console=\"fd://0,1\" or --console=\"unix:/tmp/serial.sock\")",
	                           discussion: """
	                           - --console=unix — use a Unix socket for the serial console located at ~/.tart/vms/<vm-name>/console.sock
	                           - --console=unix:/tmp/serial.sock — use a Unix socket for the serial console located at the specified path
	                           - --console=file — use a simple file for the serial console located at ~/.tart/vms/<vm-name>/console.log
	                           - --console=fd://0,1 — use file descriptors for the serial console. The first file descriptor is for reading, the second is for writing
	                           ** INFO: The console doesn't work on MacOS sonoma and earlier  **
	                           """,
	                           valueName: "url"))
	internal var console: String?

	public var consoleURL: ConsoleAttachment?
	public var forwardedPorts: [ForwardedPort] = []
	public var sockets: [SocketDevice] = []
	public var mounts: [DirectorySharingAttachment] = []
	public var networks: [BridgeAttachement] = []

	public init() {
	}

	mutating public func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		if nested && Utils.isNestedVirtualizationSupported() == false {
			self.nested = false
		}

		if let console = console {
			self.consoleURL = ConsoleAttachment(argument: console)
			try self.consoleURL!.validate()
		}

		self.sockets = self.vsock.compactMap { SocketDevice(argument: $0) }
		self.forwardedPorts = self.published.compactMap { ForwardedPort(argument: $0) }
		self.mounts = self.shares.compactMap { DirectorySharingAttachment(argument: $0) }
		self.networks = self.bridged.compactMap { BridgeAttachement(argument: $0) }
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
		return FileManager.default.fileExists(atPath: self.clientKeyURL.path()) && FileManager.default.fileExists(atPath: self.clientCertURL.path())
	}
}

public struct FullInfoReply: Sendable, Codable {
	public let name: String
	public let version: String
	public let uptime: Int64
	public let memory: MemoryInfo?
	public let cpuCount: Int32
	public let ipaddresses: [String]
	public let osname: String
	public let hostname: String
	public let release: String 

	public struct MemoryInfo: Sendable, Codable {
		public let total: UInt64
		public let free: UInt64
		public let used: UInt64

		public init(total: UInt64, free: UInt64, used: UInt64) {
			self.total = total
			self.free = free
			self.used = used
		}
	}

	public init(name: String, version: String, uptime: Int64, memory: MemoryInfo?, cpuCount: Int32, ipaddresses: [String], osname: String, hostname: String, release: String) {
		self.name = name
		self.version = version
		self.uptime = uptime
		self.memory = memory
		self.cpuCount = cpuCount
		self.ipaddresses = ipaddresses
		self.osname = osname
		self.hostname = hostname
		self.release = release
	}
}

public struct ShortInfoReply: Sendable, Codable {
	public let name: String
	public let ipaddresses: [String]
	public let cpuCount: Int32
	public let memory: UInt64

	public init(name: String, ipaddresses: [String], cpuCount: Int32, memory: UInt64) {
		self.name = name
		self.ipaddresses = ipaddresses
		self.cpuCount = cpuCount
		self.memory = memory
	}
}
