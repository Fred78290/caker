import Foundation
import System
import Virtualization
struct Utils {
	static func isNestedVirtualizationSupported() -> Bool {
		if #available(macOS 15, *) {
			return VZGenericPlatformConfiguration.isNestedVirtualizationSupported
		}

		return false
	}

	static func getHome(asSystem: Bool) throws -> URL {
		return try Home(asSystem: asSystem).homeDir
	}

	static func getOutputLog(asSystem: Bool) -> String {
		if asSystem {
			return "/Library/Logs/caked.log"
		}

		return URL(fileURLWithPath: "caked.log", relativeTo: try? Home(asSystem: false).homeDir).absoluteURL.path()
	}

	static func getListenAddress(asSystem: Bool) throws -> String {
		if let tartdListenAddress = ProcessInfo.processInfo.environment["CAKE_LISTEN_ADDRESS"] {
			return tartdListenAddress
		} else {
			var home = try Self.getHome(asSystem: asSystem)

			home.append(path: "caked.sock")

			return "unix://\(home.absoluteURL.path())"
		}
	}
}

enum FileLockError: Error, Equatable {
	case Failed(_ message: String)
	case AlreadyLocked
}

class FileLock {
	let url: URL
	let fd: Int32

	init(lockURL: URL) throws {
		url = lockURL
		fd = open(lockURL.path, 0)
	}

	deinit {
		close(fd)
	}

	func trylock() throws -> Bool {
		try flockWrapper(LOCK_EX | LOCK_NB)
	}

	func lock() throws {
		_ = try flockWrapper(LOCK_EX)
	}

	func unlock() throws {
		_ = try flockWrapper(LOCK_UN)
	}

	func flockWrapper(_ operation: Int32) throws -> Bool {
		let ret = flock(fd, operation)
		if ret != 0 {
			let details = Errno(rawValue: CInt(errno))

			if (operation & LOCK_NB) != 0 && details == .wouldBlock {
				return false
			}

			throw FileLockError.Failed("failed to lock \(url): \(details)")
		}

		return true
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
	func stringAfter(after: String) -> String {
		if let r = self.range(of: after) {
			return String(self[r.upperBound..<self.endIndex])
		} else {
			return self
		}
	}
}