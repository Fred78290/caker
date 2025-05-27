import Foundation
import GRPCLib
import System
import Virtualization

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
		case .armhf:
			return "armhf"
		case .i386:
			return "i386"
		case .i686:
			return "i686"
		case .powerpc:
			return "powerpc"
		case .ppc:
			return "ppc"
		case .ppc64el:
			return "ppc64el"
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
		case "armhf":
			self = .armhf
		case "i386":
			self = .i386
		case "i686":
			self = .i686
		case "ppc":
			self = .ppc
		case "powerpc":
			self = .powerpc
		case "ppc64el":
			self = .ppc64el
		case "riscv64":
			self = .riscv64
		case "s390x":
			self = .s390x
		case "x86_64":
			self = .x86_64
		default:
			Logger("Architecture").warn("Unknown architecture: \(rawValue)")
			// Default to amd64 if unknown
			// This is a fallback and should be handled better
			// in the future.
			self = .amd64
		}
	}

	case arm64
	case amd64
	case aarch64
	case armv7l
	case armhf
	case i386
	case i686
	case powerpc
	case ppc
	case ppc64el
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

func processExist(_ runningPID: pid_t) throws -> Bool {
	// Requesting the pid of 0 from systcl will return all pids
	var mib = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
	var bufferSize = 0

	// To find the needed buffer size you call sysctl with a nil results pointer.
	// This sets the size of the buffer needed in the bufferSize pointer.
	if sysctl(&mib, UInt32(mib.count), nil, &bufferSize, nil, 0) < 0 {
		throw ServiceError(errno)
	}

	// Determine how many kinfo_proc struts will be returned.
	// Using stride rather than size will take alligment into account.
	let entryCount = bufferSize / MemoryLayout<kinfo_proc>.stride

	// Create our buffer to be filled with the list of processes and allocate it.
	// Use defer to make sure it's deallocated when the scope ends.
	var procList: UnsafeMutablePointer<kinfo_proc>?
	procList = UnsafeMutablePointer.allocate(capacity: bufferSize)
	defer {
		procList?.deallocate()
	}

	// Now we actually perform our query to get all the processes.
	if sysctl(&mib, UInt32(mib.count), procList, &bufferSize, nil, 0) < 0 {
		throw ServiceError(errno)
	}

	// Simply step through the returned bytes and lookup the data you want.
	// If the pid is 0 that means it's invalid and should be ignored.
	for index in 0...entryCount {
		guard let pid = procList?[index].kp_proc.p_pid, pid != 0 else {
			continue
		}

		if runningPID == pid {
			return true
		}
	}

	return false
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

	func killPID(_ signal: Int32) -> Int32 {
		guard let pid = try? String(contentsOf: self, encoding: .ascii) else {
			return ENODATA
		}

		guard let pid: Int32 = Int32(pid.trimmingCharacters(in: .whitespacesAndNewlines)) else {
			return EINVAL
		}

		return kill(pid, SIGTERM)
	}

	func isPIDRunning() -> Bool {
		if let pid = readPID() {
			do {
				return try processExist(pid_t(pid))
			} catch {
				Logger(self).error("Error checking if PID \(pid) is running: \(error)")
			}
		}

		return false
	}

	typealias WaitPIDHandler = () throws -> Void

	func waitStopped(maxRetries: Int = 10, handler: WaitPIDHandler? = nil) throws {
		var retries = 0

		if let pid = readPID() {
			while retries < maxRetries {
				if let handler = handler {
					try handler()
				}

				if FileManager.default.fileExists(atPath: self.path) == false {
					return
				}

				if let exist = try? processExist(pid_t(pid)), exist == false {
					return
				}

				Thread.sleep(forTimeInterval: 1)

				retries += 1
			}

			throw ServiceError("PID file \(self.path) did not stopped within the expected time")
		}
	}

	func waitPID(maxRetries: Int = 10, handler: WaitPIDHandler? = nil) throws {
		var retries = 0

		while retries < maxRetries {
			if let handler = handler {
				try handler()
			}

			if FileManager.default.fileExists(atPath: self.path) {
				if self.isPIDRunning() {
					Logger(self).info("PID file exists at \(self.path)")
					return
				}

				throw ServiceError("PID file exists at \(self.path) but process died")
			}

			Thread.sleep(forTimeInterval: 1)

			retries += 1
		}

		throw ServiceError("PID file \(self.path) did not appear within the expected time")
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
		try self.resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize!
	}

	func allocatedSizeBytes() throws -> Int {
		try self.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize!
	}

	func accessDate() throws -> Date {
		let attrs = try self.resourceValues(forKeys: [.contentAccessDateKey])
		return attrs.contentAccessDate!
	}

	func updateAccessDate(_ accessDate: Date = Date()) throws {
		let attrs = try self.resourceValues(forKeys: [.contentAccessDateKey])
		let modificationDate = attrs.contentAccessDate!

		let times = [accessDate.asTimeval(), modificationDate.asTimeval()]
		let ret = utimes(path, times)
		if ret != 0 {
			let details = Errno(rawValue: CInt(errno))

			throw ServiceError("utimes(2) failed: \(details)")
		}
	}
}

extension DirectorySharingAttachments {
	public var multipleDirectoryShares: VZDirectoryShare {
		var directories: [String: VZSharedDirectory] = [:]

		self.forEach {
			if let config = $0.configuration {
				directories[$0.human] = config
			}
		}

		return VZMultipleDirectoryShare(directories: directories)
	}

	public var singleDirectoryShares: [VZDirectoryShare] {
		self.compactMap { mount in
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

		return self.compactMap { mount in
			let sharingDevice = VZVirtioFileSystemDeviceConfiguration(tag: mount.name)

			sharingDevice.share = VZSingleDirectoryShare(directory: .init(url: mount.path, readOnly: mount.readOnly))

			return sharingDevice
		}
	}
}
