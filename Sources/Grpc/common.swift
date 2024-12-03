import Foundation
import ArgumentParser
import Virtualization

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

public struct ForwardedPort: Codable {
	public enum ForwardedProtocol: String, Codable {
		case tcp
		case udp
		case both
		case none
	}

	public var proto: ForwardedProtocol = .tcp
	public var host: Int = -1
	public var guest: Int = -1
}

extension ForwardedPort: CustomStringConvertible, ExpressibleByArgument {
	public var description: String {
		"\(host):\(guest)/\(proto)"
	}

	public init(argument: String) {
		let expr = try! NSRegularExpression(pattern: #"(?<host>\d+)(:(?<guest>\d+)(\/(?<proto>tcp|udp|both))?)?"#, options: [])
		let range = NSRange(argument.startIndex..<argument.endIndex, in: argument)

		guard let match = expr.firstMatch(in: argument, options: [], range: range) else {
			return
		}

		if let hostRange = Range(match.range(withName: "host"), in: argument) {
			self.host = Int(argument[hostRange]) ?? 0
		}

		if let guestRange = Range(match.range(withName: "guest"), in: argument) {
			self.guest = Int(argument[guestRange]) ?? 0
		} else {
			self.guest = self.host
		}

		self.proto = .tcp

		if let protoRange = Range(match.range(withName: "proto"), in: argument) {
			if let proto = ForwardedProtocol(rawValue: String(argument[protoRange])) {
				self.proto = proto
			}
		}
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
	public var forwardedPort: [ForwardedPort] = []

	@Flag(name: [.customLong("reset-publish")], help: ArgumentHelp("Reset published port."))
	public var resetForwardedPort: Bool = false

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Additional directory shares with an optional read-only and mount tag options (e.g. --dir=\"~/src/build\" or --dir=\"~/src/sources:ro\")", discussion: "See tart help for more infos", valueName: "[name:]path[:options]"))
	public var mount: [String] = ["unset"]

	@Option(help: ArgumentHelp("Use bridged networking instead of the default shared (NAT) networking \n(e.g. --net-bridged=en0 or --net-bridged=\"Wi-Fi\")", discussion: "See tart help for more infos", valueName: "interface name"))
	public var netBridged: [String] = ["unset"]

	@Option(help: ArgumentHelp("Use software networking instead of the default shared (NAT) networking", discussion: "See tart help for more infos"))
	public var netSoftnet: Bool? = nil

	@Option(help: ArgumentHelp("Comma-separated list of CIDRs to allow the traffic to when using Softnet isolation\n(e.g. --net-softnet-allow=192.168.0.0/24)", valueName: "comma-separated CIDRs"))
	public var netSoftnetAllow: String? = nil

	@Option(help: ("Restrict network access to the host-only network"))
	public var netHost: Bool? = nil

	@Flag(help: ArgumentHelp("Generate a new random MAC address for the VM."))
	public var randomMAC: Bool = false

	public var mounts: [String]? {
		get {
			if mount.contains("unset") == false {
				return nil
			}
			
			return mount
		}
	}

	public var bridged: [String]? {
		get {
			if netBridged.contains("unset") == false {
				return nil
			}
			
			return netBridged
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

	@Option(help: ArgumentHelp("Optional cloud-init user-data file path for linux VM", valueName: "path"))
	public var userData: String?

	@Option(help: ArgumentHelp("Optional cloud-init network-config file path for linux VM", valueName: "path"))
	public var networkConfig: String?

	@Flag(help: ArgumentHelp("Whether to automatically reconfigure the VM's display to fit the window"))
	public var displayRefit: Bool = false

	@Option(name: [.customLong("publish"), .customShort("p")], help: ArgumentHelp("Optional forwarded port for VM, syntax like docker", valueName: "host:guest/(tcp|udp|both)"))
	public var forwardedPort: [ForwardedPort] = []

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Additional directory shares with an optional read-only and mount tag options (e.g. --dir=\"~/src/build\" or --dir=\"~/src/sources:ro\")", discussion: "See tart help for more infos", valueName: "[name:]path[:options]"))
	public var mounts: [String] = []

	@Option(help: ArgumentHelp("Use bridged networking instead of the default shared (NAT) networking \n(e.g. --net-bridged=en0 or --net-bridged=\"Wi-Fi\")", discussion: "See tart help for more infos", valueName: "interface name"))
	public var netBridged: [String] = []

	@Flag(help: ArgumentHelp("Use software networking instead of the default shared (NAT) networking", discussion: "See tart help for more infos"))
	public var netSoftnet: Bool = false

	@Option(help: ArgumentHelp("Comma-separated list of CIDRs to allow the traffic to when using Softnet isolation\n(e.g. --net-softnet-allow=192.168.0.0/24)", valueName: "comma-separated CIDRs"))
	public var netSoftnetAllow: String?

	@Flag(help: ArgumentHelp("Restrict network access to the host-only network"))
	public var netHost: Bool = false

	public init() {
	}

	public func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		var netFlags = 0
		if netBridged.count > 0 { netFlags += 1 }
		if netSoftnet { netFlags += 1 }
		if netHost { netFlags += 1 }

		if netFlags > 1 {
			throw ValidationError("--net-bridged, --net-softnet and --net-host are mutually exclusive")
		}
	}
}
