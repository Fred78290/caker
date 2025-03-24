import Foundation
import System
import Virtualization
import GRPCLib

enum Architecture: String, Codable, CustomStringConvertible {
	var description: String {
		switch self {
		case .arm64:
			return "aarch64"
		case .amd64:
			return "x86_64"
		case .aarch64:
			return "aarch64"
		case .armv7l:
			return "armv7l"
		case .i686:
			return "i686"
		case .ppc:
			return "ppc"
		case .ppc64le:
			return "ppc64le"
		case .riscv64:
			return "riscv64"
		case .s390x:
			return "s390x"
		case .x86_64:
			return "x86_64"
		}
	}

	init(rawValue: String) {
		switch rawValue {
		case "arm64":
			self = .arm64
		case "amd64":
			self = .amd64
		case "aarch64":
			self = .aarch64
		case "armv7l":
			self = .armv7l
		case "i686":
			self = .i686
		case "ppc":
			self = .ppc
		case "ppc64le":
			self = .ppc64le
		case "riscv64":
			self = .riscv64
		case "s390x":
			self = .s390x
		case "x86_64":
			self = .x86_64
		default:
			self = .amd64
		}
	}

	case arm64
	case amd64
	case aarch64
	case armv7l
	case i686
	case ppc
	case ppc64le
	case riscv64
	case s390x
	case x86_64

	static func current() -> Architecture {
		#if arch(arm64)
			return .arm64
		#elseif arch(x86_64)
			return .amd64
		#endif
	}
}

extension Date {
	func asTimeval() -> timeval {
		timeval(tv_sec: Int(timeIntervalSince1970), tv_usec: 0)
	}
}

extension URL: Purgeable {
	var url: URL {
		self
	}

	func writePID() throws {
		let pid = getpid()

		try "\(pid)".write(to: self, atomically: true, encoding: .ascii)
	}

	func readPID() -> Int32? {
		guard let pid = try? String(contentsOf: self, encoding: .ascii) else {
			return nil
		}

		guard let pid: Int32 = Int32(pid.trimmingCharacters(in: .whitespacesAndNewlines)) else {
			return nil
		}

		return pid
	}

	func isPIDRunning() -> Bool {
		if let pid = readPID() {
			return kill(pid, 0) == 0
		}

		return false
	}

	static func binary(_ name: String) -> URL? {
		let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/usr/local/bin:/bin:/sbin:/usr/sbin:/opt/bin"

		return path.split(separator: ":").compactMap { dir in
			let url: URL = URL(fileURLWithPath: String(dir)).appendingPathComponent(name, isDirectory: false).resolvingSymlinksInPath()

			if FileManager.default.fileExists(atPath: url.path) {
				return url.absoluteURL
			}

			return nil
		}.first
	}

	func source() -> String {
		self.deletingLastPathComponent().lastPathComponent
	}

	func name() -> String {
		self.lastPathComponent.stringBeforeLast(before: ".")
	}

	func exists() throws -> Bool {
		if self.isFileURL || self.scheme == "unix" || self.scheme == "vsock" {
			return FileManager.default.fileExists(atPath: self.absoluteURL.path)
		}

		throw ServiceError("Not a file URL: \(self.absoluteString)")
	}

	func deleteIfFileExists() throws {
		if self.isFileURL || self.scheme == "unix" || self.scheme == "vsock" {
			if FileManager.default.fileExists(atPath: self.absoluteURL.path) {
				try FileManager.default.removeItem(at: URL(fileURLWithPath: self.absoluteURL.path))
			}
		}
	}

	func delete() throws {
		try FileManager.default.removeItem(at: self)
	}

	func sizeBytes() throws -> Int {
		try resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize!
	}

	func allocatedSizeBytes() throws -> Int {
		try resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize!
	}

	func accessDate() throws -> Date {
		let attrs = try resourceValues(forKeys: [.contentAccessDateKey])
		return attrs.contentAccessDate!
	}

	func updateAccessDate(_ accessDate: Date = Date()) throws {
		let attrs = try resourceValues(forKeys: [.contentAccessDateKey])
		let modificationDate = attrs.contentAccessDate!

		let times = [accessDate.asTimeval(), modificationDate.asTimeval()]
		let ret = utimes(path, times)
		if ret != 0 {
			let details = Errno(rawValue: CInt(errno))

			throw ServiceError("utimes(2) failed: \(details)")
		}
	}
}

extension String {
	var expandingTildeInPath: String {
		if self.hasPrefix("~") {
			return NSString(string: self).expandingTildeInPath
		}

		return self
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

public typealias DirectorySharingAttachments = [DirectorySharingAttachment]

extension DirectorySharingAttachments {
	public var multipleDirectoryShares: VZDirectoryShare {
		var directories: [String : VZSharedDirectory] = [:]

		self.forEach {
			if let config = $0.configuration {
				directories[$0.human] = config
			}
		}

		return VZMultipleDirectoryShare(directories: directories)
	}

	public var singleDirectoryShares: [VZDirectoryShare] {
		self.compactMap{ mount in
			VZSingleDirectoryShare(directory: .init(url: mount.path, readOnly: mount.readOnly))
		}
	}

	func directorySharingAttachments(os: VirtualizedOS) -> [VZDirectorySharingDeviceConfiguration] {
		if self.isEmpty {
			return []
		}

		if os == .darwin {
			let sharingDevice = VZVirtioFileSystemDeviceConfiguration(tag: VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag)

			sharingDevice.share = self.multipleDirectoryShares

			return [sharingDevice]
		}

		return self.compactMap{ mount in
			let sharingDevice = VZVirtioFileSystemDeviceConfiguration(tag: mount.name)

			sharingDevice.share = VZSingleDirectoryShare(directory: .init(url: mount.path, readOnly: mount.readOnly))

			return sharingDevice
		}
	}
}

