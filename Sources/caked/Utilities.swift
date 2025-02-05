import Foundation
import System

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

	func source() -> String {
		self.deletingLastPathComponent().lastPathComponent
	}

	func name() -> String {
		self.lastPathComponent.stringBeforeLast(before: ".")
	}

	func exists() throws -> Bool {
		if self.isFileURL {
			return FileManager.default.fileExists(atPath: self.absoluteURL.path())
		}

		throw ServiceError("Not a file URL: \(self.absoluteString)")
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
}
