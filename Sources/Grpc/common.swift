import ArgumentParser
import Foundation
import NIOPortForwarding
import Security
import System
import Virtualization

public let defaultUbuntuImage = "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img"

internal let cloudimage_help =
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

internal let network_help =
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

internal let socket_help =
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

internal let console_help =
	"""

	  - --console=unix — use a Unix socket for the serial console located at ~/.tart/vms/<vm-name>/console.sock
	  - --console=unix:/tmp/serial.sock — use a Unix socket for the serial console located at the specified path
	  - --console=file — use a simple file for the serial console located at ~/.tart/vms/<vm-name>/console.log
	  - --console=fd://0,1 — use file descriptors for the serial console. The first file descriptor is for reading, the second is for writing
	    ** INFO: The console doesn't work on MacOS sonoma and earlier  **

	"""

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
	private static var homeDirectories: [Bool: URL] = [:]

	public static func isNestedVirtualizationSupported() -> Bool {
		if #available(macOS 15, *) {
			return VZGenericPlatformConfiguration.isNestedVirtualizationSupported
		}

		return false
	}

	public static func getHome(asSystem: Bool = false, createItIfNotExists: Bool = true) throws -> URL {
		guard let cakeHomeDir = homeDirectories[asSystem] else {
			var cakeHomeDir: URL

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

			cakeHomeDir = cakeHomeDir.resolvingSymlinksInPath()

			homeDirectories[asSystem] = cakeHomeDir

			return cakeHomeDir
		}

		return cakeHomeDir
	}

	public static func getDefaultServerAddress(asSystem: Bool) throws -> String {
		if let cakeListenAddress = ProcessInfo.processInfo.environment["CAKE_LISTEN_ADDRESS"] {
			return cakeListenAddress
		} else {
			return try Utils.getHome(asSystem: asSystem).socketPath(name: "caked").absoluteString
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

let fingerprint64 = try! NSRegularExpression(pattern: "^[0-9a-fA-F]{64}$")
let fingerprint12 = try! NSRegularExpression(pattern: "^[0-9a-fA-F]{12}$")

extension String {
	public func isFingerPrint() -> Bool {
		if fingerprint64.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.count)) != nil {
			return true
		}

		if fingerprint12.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.count)) != nil {
			return true
		}

		return false
	}

	public var expandingTildeInPath: String {
		if self.hasPrefix("~") {
			return NSString(string: self).expandingTildeInPath
		}

		return self
	}

	public init(errno: Errno) {
		self = String(cString: strerror(errno.rawValue))
	}

	public init(errno: Int32) {
		self = String(cString: strerror(errno))
	}

	public func stringBeforeLast(before: Character) -> String {
		if let r = self.lastIndex(of: before) {
			return String(self[self.startIndex..<r])
		} else {
			return self
		}
	}

	public func stringAfterLast(before: Character) -> String {
		if let r = self.lastIndex(of: before) {
			guard let start = self.index(r, offsetBy: 1, limitedBy: self.endIndex) else {
				return ""
			}
			return String(self[start..<self.endIndex])
		} else {
			return self
		}
	}

	public func stringBefore(before: String) -> String {
		if let r = self.range(of: before) {
			return String(self[self.startIndex..<r.lowerBound])
		} else {
			return self
		}
	}

	public func stringAfter(after: String) -> String {
		if let r = self.range(of: after) {
			return String(self[r.upperBound..<self.endIndex])
		} else {
			return self
		}
	}

	public func substring(_ bounds: PartialRangeUpTo<Int>) -> String {
		guard let endIndex = self.index(self.startIndex, offsetBy: bounds.upperBound, limitedBy: self.endIndex) else {
			return self
		}

		return String(self[self.startIndex..<endIndex])
	}

	public func substring(_ bounds: Range<Int>) -> String {
		guard let startIndex = self.index(self.startIndex, offsetBy: bounds.lowerBound, limitedBy: self.endIndex) else {
			return ""
		}

		guard let endIndex = self.index(self.startIndex, offsetBy: bounds.upperBound, limitedBy: self.endIndex) else {
			return self
		}

		return String(self[startIndex..<endIndex])
	}

}

extension URL {
	public func socketPath(name: String) -> URL {
		let socketPath = self.appendingPathComponent("\(name).sock", isDirectory: false).absoluteURL

		if socketPath.path.utf8.count < 103 {
			return URL(string: "unix://\(socketPath.path)")!
		} else {
			return URL(string: "unix:///tmp/\(name)-\(self.lastPathComponent).sock")!
		}
	}
}
