import ArgumentParser
import Dynamic
import Foundation
import NIOPortForwarding
import ObjectiveC
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

	  - --console=unix — use a Unix socket for the serial console located at ~/.caked/vms/<vm-name>/console.sock
	  - --console=unix:/tmp/serial.sock — use a Unix socket for the serial console located at the specified path
	  - --console=file — use a simple file for the serial console located at ~/.caked/vms/<vm-name>/console.log
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

	public enum RunMode: Sendable {
		case system
		case user
		case app

		public var isSystem: Bool {
			return self == .system
		}

		public var isUser: Bool {
			return self != .system
		}
	}

	public static func isNestedVirtualizationSupported() -> Bool {
		if #available(macOS 15, *) {
			return VZGenericPlatformConfiguration.isNestedVirtualizationSupported
		}

		return false
	}

	public static func getHome(runMode: RunMode, createItIfNotExists: Bool = true) throws -> URL {
		guard let cakeHomeDir = homeDirectories[runMode.isSystem] else {
			var cakeHomeDir: URL

			if let customHome = ProcessInfo.processInfo.environment["CAKE_HOME"] {
				cakeHomeDir = URL(fileURLWithPath: customHome)
			} else if runMode.isSystem || geteuid() == 0 {
				let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .systemDomainMask, true)
				var applicationSupportDirectory = URL(fileURLWithPath: paths.first!, isDirectory: true)

				applicationSupportDirectory = URL(
					fileURLWithPath: cakerSignature,
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

			homeDirectories[runMode.isSystem] = cakeHomeDir

			return cakeHomeDir
		}

		return cakeHomeDir
	}

	public static func getDefaultServerAddress(runMode: RunMode) throws -> String {
		if let cakeListenAddress = ProcessInfo.processInfo.environment["CAKE_LISTEN_ADDRESS"] {
			return cakeListenAddress
		} else {
			return try Utils.getHome(runMode: runMode).socketPath(name: "caked").absoluteString
		}
	}

	public static func getOutputLog(runMode: RunMode) -> String {
		if runMode.isSystem {
			return "/Library/Logs/caked.log"
		}

		return URL(fileURLWithPath: "caked.log", relativeTo: try? getHome(runMode: runMode)).absoluteURL.path
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

	public static func getCertificats(runMode: Utils.RunMode) throws -> ClientCertificatesLocation {
		return ClientCertificatesLocation(certHome: URL(fileURLWithPath: "certs", isDirectory: true, relativeTo: try Utils.getHome(runMode: runMode)))
	}

	public func exists() -> Bool {
		return FileManager.default.fileExists(atPath: self.clientKeyURL.path) && FileManager.default.fileExists(atPath: self.clientCertURL.path)
	}
}

extension String {
	public static let fingerprint64 = try! NSRegularExpression(pattern: "^[0-9a-fA-F]{64}$")
	public static let fingerprint12 = try! NSRegularExpression(pattern: "^[0-9a-fA-F]{12}$")
	public static let grpcSeparator: String = "|"

	public func isFingerPrint() -> Bool {
		if Self.fingerprint64.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.count)) != nil {
			return true
		}

		if Self.fingerprint12.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.count)) != nil {
			return true
		}

		return false
	}

	public var deletingPathExtension: String {
		return (self as NSString).deletingPathExtension
	}

	public var expandingTildeInPath: String {
		if self.hasPrefix("~") {
			return (self as NSString).expandingTildeInPath
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

	public func stringAfterLast(after: Character) -> String {
		if let r = self.lastIndex(of: after) {
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

	public func base64EncodedString() -> String {
		self.data(using: .ascii)?.base64EncodedString() ?? ""
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

	public func fileSize() throws -> UInt64 {
		guard self.isFileURL else {
			throw NSError(domain: NSOSStatusErrorDomain, code: Int(Errno.badAddress.rawValue), userInfo: ["description": "not a file url"])
		}
		let attrs = try FileManager.default.attributesOfItem(atPath: self.absoluteURL.path(percentEncoded: false))

		return (attrs[.size] as? NSNumber)?.uint64Value ?? 0
	}

	public func fileReference() -> String? {
		guard self.isFileURL else {
			return nil
		}

		let url: NSURL = NSURL(fileURLWithPath: self.absoluteURL.path(percentEncoded: false))
		let dyn = Dynamic(url, memberName: "fileReferenceURL")

		return dyn.asString
	}
}

extension FileWrapper {
	public var contentsURL: NSURL? {
		guard let field = class_getInstanceVariable(FileWrapper.self, "_contentsURL") else {
			return nil
		}

		guard let value = object_getIvar(self, field) as? NSURL else {
			return nil
		}

		return value
	}
}

extension FileManager {
	// Applique récursivement les attributs à tous les fichiers et dossiers d'un chemin
	public func setAttributesRecursively(_ attributes: [FileAttributeKey: Any], atPath path: String) throws {
		var isDir: ObjCBool = false

		if self.fileExists(atPath: path, isDirectory: &isDir) {
			try self.setAttributes(attributes, ofItemAtPath: path)

			if isDir.boolValue {
				let contents = try self.contentsOfDirectory(atPath: path)

				for item in contents {
					let fullPath = (path as NSString).appendingPathComponent(item)

					try self.setAttributesRecursively(attributes, atPath: fullPath)
				}
			}
		}
	}
}

extension NSView {
	public func screenCoordinates() -> CGRect {
		return self.window!.convertToScreen(self.convert(self.bounds, to: nil))
	}

	public func imageRepresentation(in bounds: NSRect) -> NSBitmapImageRep? {
		if let imageRepresentation = bitmapImageRepForCachingDisplay(in: bounds) {
			cacheDisplay(in: bounds, to: imageRepresentation)

			return imageRepresentation
		}

		return nil
	}

	public func image(in bounds: NSRect) -> NSImage? {
		if let imageRepresentation = imageRepresentation(in: bounds), let cgImage = imageRepresentation.cgImage {
			return NSImage(cgImage: cgImage, size: bounds.size)
		}

		return nil
	}

	public func image() -> NSImage {
		self.image(in: self.bounds)!
	}
}

extension NSWindow {
	public func resizeContentView(to size: CGSize, animated: Bool) {
		let titleBarHeight: CGFloat = self.frame.height - self.contentLayoutRect.height
		var frame = self.frame

		frame = self.frameRect(forContentRect: NSMakeRect(frame.origin.x, frame.origin.y, size.width, size.height + titleBarHeight))
		frame.origin.y += self.frame.size.height
		frame.origin.y -= frame.size.height

		self.setFrame(frame, display: true, animate: animated)
	}
}

extension NSImage {
	public var pngData: Data? {
		guard let cgref = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
			return nil
		}

		let newrep = NSBitmapImageRep(cgImage: cgref)
		newrep.size = self.size
		return newrep.representation(using: .png, properties: [:])
	}

	public var cgImage: CGImage? {
		return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
	}

	public func blurred(radius: CGFloat = 10.0) -> NSImage? {
		guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
			return nil
		}

		let ciImage = CIImage(cgImage: cgImage)
		let filter = CIFilter(name: "CIGaussianBlur")

		filter?.setValue(ciImage, forKey: kCIInputImageKey)
		filter?.setValue(radius, forKey: kCIInputRadiusKey)

		guard let outputImage = filter?.outputImage else {
			return nil
		}

		let ciContext = CIContext()
		let rect = CGRect(origin: .zero, size: self.size)

		guard let cgBlurred = ciContext.createCGImage(outputImage, from: rect) else {
			return nil
		}

		let blurredImage = NSImage(size: self.size)

		blurredImage.lockFocus()

		NSGraphicsContext.current?.cgContext.draw(cgBlurred, in: rect)

		blurredImage.unlockFocus()

		return blurredImage
	}
}
