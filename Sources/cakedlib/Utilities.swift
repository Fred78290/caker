import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Socket
import System
import Virtualization

public enum Architecture: String, Codable, CustomStringConvertible {
	public var description: String {
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

	public init(rawValue: String) {
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

	public static func current() -> Architecture {
		#if arch(arm64)
			return .arm64
		#elseif arch(x86_64)
			return .amd64
		#endif
	}
}

extension Date {
	public func asTimeval() -> timeval {
		timeval(tv_sec: Int(timeIntervalSince1970), tv_usec: 0)
	}
}

public func processExist(_ runningPID: pid_t) throws -> (running: Bool, processName: String, pid: pid_t) {
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
		guard let proc = procList?[index] else {
			continue
		}

		if proc.kp_proc.p_pid != 0 && runningPID == proc.kp_proc.p_pid {
			let comm = proc.kp_proc.p_comm
			let name = String(cString: Mirror(reflecting: comm).children.map { $0.value as! CChar })

			return (true, name, runningPID)
		}
	}

	return (false, "", runningPID)
}

extension URL: Purgeable {
	public var fingerprint: String? {
		nil
	}

	public var url: URL {
		self
	}

	public func writePID() throws {
		let pid = getpid()

		try "\(pid)".write(to: self, atomically: true, encoding: .ascii)
	}

	public func readPID() -> Int32? {
		if FileManager.default.fileExists(atPath: self.absoluteURL.path) == false {
			return nil
		}

		guard let pid = try? String(contentsOf: self, encoding: .ascii) else {
			return nil
		}

		guard let pid: Int32 = Int32(pid.trimmingCharacters(in: .whitespacesAndNewlines)) else {
			return nil
		}

		return pid
	}

	public func killPID(_ signal: Int32) -> Int32 {
		if FileManager.default.fileExists(atPath: self.absoluteURL.path) == false {
			return ENODATA
		}

		guard let pid = try? String(contentsOf: self, encoding: .ascii) else {
			return ENODATA
		}

		guard let pid: Int32 = Int32(pid.trimmingCharacters(in: .whitespacesAndNewlines)) else {
			return EINVAL
		}

		return kill(pid, SIGTERM)
	}

	public func isPIDRunning() -> (running: Bool, processName: String, pid: Int32?) {
		if let pid = readPID() {
			do {
				return try processExist(pid_t(pid))
			} catch {
				Logger(self).error("Error checking if PID \(pid) is running: \(error)")
			}
		}

		return (false, "", nil)
	}

	public func isPIDRunning(_ expectedProcessName: String) -> Bool {
		let pid = self.isPIDRunning()

		return pid.0 && pid.1.contains(expectedProcessName)
	}

	public func isCakedRunning() -> Bool {
		self.isPIDRunning(Home.cakedCommandName)
	}

	public typealias WaitPIDHandler = () throws -> Void

	public func waitStopped(maxRetries: Int = 10, handler: WaitPIDHandler? = nil) throws {
		var retries = 0

		if let pid = readPID() {
			while retries < maxRetries {
				if let handler = handler {
					try handler()
				}

				if FileManager.default.fileExists(atPath: self.path) == false {
					return
				}

				if let exist = try? processExist(pid_t(pid)), exist.0 == false {
					return
				}

				Thread.sleep(forTimeInterval: 1)

				retries += 1
			}

			throw ServiceError("PID file \(self.path) did not stopped within the expected time")
		}
	}

	public func waitPID(maxRetries: Int = 10, handler: WaitPIDHandler? = nil) throws {
		var retries = 0

		while retries < maxRetries {
			if let handler = handler {
				try handler()
			}

			if FileManager.default.fileExists(atPath: self.path) {
				if self.isPIDRunning().0 {
					#if DEBUG
						Logger(self).debug("PID file exists at \(self.path)")
					#endif
					return
				}

				throw ServiceError("PID file exists at \(self.path) but process died")
			}

			Thread.sleep(forTimeInterval: 1)

			retries += 1
		}

		throw ServiceError("PID file \(self.path) did not appear within the expected time")
	}

	public static func binary(_ name: String) -> URL? {
		if let executablePath = Bundle.main.path(forAuxiliaryExecutable: name) {
			let url = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath().absoluteURL
			
			if FileManager.default.fileExists(atPath: url.path) {
				return url
			}
		}

		let pathd = [
			Bundle.main.builtInPlugInsPath,
			Bundle.main.privateFrameworksPath,
			Bundle.main.sharedFrameworksPath,
			Bundle.main.sharedSupportPath,
			Bundle.main.resourcePath,
			ProcessInfo.processInfo.environment["PATH"],
			"/usr/bin:/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/sbin:/opt/bin:/opt/sbin"]

		return pathd.compactMap {
			guard let path = $0 else {
				return nil
			}

			return path.split(separator: ":").compactMap { dir in
				let url: URL = URL(fileURLWithPath: String(dir)).appendingPathComponent(name, isDirectory: false).resolvingSymlinksInPath().absoluteURL

				if FileManager.default.fileExists(atPath: url.path) {
					return url
				}

				return nil
			}.first
		}.first
	}

	public var source: String {
		self.deletingLastPathComponent().lastPathComponent
	}

	public var name: String {
		self.lastPathComponent.stringBeforeLast(before: ".")
	}

	public var fileExists: Bool {
		guard let found = try? self.exists() else {
			return false
		}

		return found
	}

	public func exists() throws -> Bool {
		if self.isFileURL || self.scheme == "unix" || self.scheme == "vsock" {
			return FileManager.default.fileExists(atPath: self.absoluteURL.path)
		}

		throw ServiceError("Not a file URL: \(self.absoluteString)")
	}

	public func deleteIfFileExists() throws {
		if self.isFileURL || self.scheme == "unix" || self.scheme == "vsock" {
			if FileManager.default.fileExists(atPath: self.absoluteURL.path) {
				try FileManager.default.removeItem(at: URL(fileURLWithPath: self.absoluteURL.path))
			}
		}
	}

	public func delete() throws {
		try FileManager.default.removeItem(at: self)
	}

	public func sizeBytes() throws -> Int {
		if self.isDirectory {
			var totalFileSize: Int = 0

			if let fileURLs: FileManager.DirectoryEnumerator = FileManager.default.enumerator(at: self, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], options: .skipsHiddenFiles) {
				for case let fileURL as URL in fileURLs {
					totalFileSize += try fileURL.sizeBytes()
				}
			}

			return totalFileSize
		} else if self.isFileURL {
			guard let totalFileSize = try self.resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize else {
				return 0
			}

			return totalFileSize
		} else {
			throw ServiceError("Not a file URL: \(self.absoluteString)")
		}
	}

	public func allocatedSizeBytes() throws -> Int {
		if self.isDirectory {
			var totalFileAllocatedSize = 0

			if let fileURLs: FileManager.DirectoryEnumerator = FileManager.default.enumerator(at: self, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], options: .skipsHiddenFiles) {
				for case let fileURL as URL in fileURLs {
					totalFileAllocatedSize += try fileURL.allocatedSizeBytes()
				}
			}

			return totalFileAllocatedSize
		} else if self.isFileURL {
			guard let totalFileAllocatedSize = try self.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize else {
				return 0
			}

			return totalFileAllocatedSize
		} else {
			throw ServiceError("Not a file URL: \(self.absoluteString)")
		}
	}

	public func accessDate() throws -> Date {
		let attrs = try self.resourceValues(forKeys: [.contentAccessDateKey])
		return attrs.contentAccessDate!
	}

	public func updateAccessDate(_ accessDate: Date = Date()) throws {
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

	public func directorySharingAttachments(os: VirtualizedOS) -> [VZDirectorySharingDeviceConfiguration] {
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

extension Socket {
	static func create(host: String, port: Int) throws -> Socket {
		let signature = try Socket.Signature(protocolFamily: .inet, socketType: .stream, proto: .tcp, hostname: "localhost", port: Int32(port))!

		return try Socket.create(connectedUsing: signature)
	}
}

public struct Utilities {
	public static let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
	public static let keychainID = "com.aldunelabs.caker"

	public static func cakeagentBinary(os: VirtualizedOS, runMode: Utils.RunMode, observer: ProgressObserver? = nil) async throws -> URL {
		let arch = Architecture.current().rawValue
		let os = os.rawValue
		let home: Home = try Home(runMode: runMode)
		let localAgent = home.agentDirectory.appendingPathComponent("cakeagent-\(CAKEAGENT_SNAPSHOT)-\(os)-\(arch)", isDirectory: false)

		if FileManager.default.fileExists(atPath: localAgent.path) == false {
			guard let remoteURL = URL(string: "https://github.com/Fred78290/cakeagent/releases/download/SNAPSHOT-\(CAKEAGENT_SNAPSHOT)/cakeagent-\(os)-\(arch)") else {
				throw ServiceError("unable to get remote cakeagent")
			}

			try await Curl(fromURL: remoteURL).get(store: localAgent)
		}

		return localAgent
	}

	public static func createCakeAgentClient(on: EventLoopGroup, runMode: Utils.RunMode, rootURL: URL, connectionTimeout: Int64 = 30, retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentClient {

		let certificates = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		let listeningAddress = try VMLocation.newVMLocation(rootURL: rootURL).agentURL

		return try CakeAgentHelper.createClient(
			on: on,
			listeningAddress: listeningAddress,
			connectionTimeout: connectionTimeout,
			caCert: certificates.caCertURL.path,
			tlsCert: certificates.clientCertURL.path,
			tlsKey: certificates.clientKeyURL.path,
			retries: retries
		)
	}

	public static func createCakeAgentClient(on: EventLoopGroup, runMode: Utils.RunMode, name: String, connectionTimeout: Int64 = 30, retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentClient {
		let certificates = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		let listeningAddress = try StorageLocation(runMode: runMode).find(name).agentURL

		return try CakeAgentHelper.createClient(
			on: on,
			listeningAddress: listeningAddress,
			connectionTimeout: connectionTimeout,
			caCert: certificates.caCertURL.path,
			tlsCert: certificates.clientCertURL.path,
			tlsKey: certificates.clientKeyURL.path,
			retries: retries
		)
	}

	public static func waitPortReady(host: String = "", port: Int, timeout: TimeInterval = 60) -> Bool {
		let start = Date()

		while Date().timeIntervalSince(start) < timeout {
			do {
				let socket = try Socket.create(host: host, port: port)
				socket.close()
				return true
			} catch {
			}

			Thread.sleep(forTimeInterval: 0.05)
		}

		return false
	}

	public static func findFreePort() throws -> Int {
		let socketFD = socket(AF_INET, SOCK_STREAM, 0)

		if socketFD == -1 {
			throw ServiceError(errno)
		}

		defer {
			close(socketFD)
		}

		var addr = sockaddr_in()

		addr.sin_family = sa_family_t(AF_INET)
		addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
		addr.sin_port = in_port_t(0).bigEndian

		let bindResult = withUnsafePointer(to: &addr) {
			$0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
				bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
			}
		}

		guard bindResult == 0 else {
			throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
		}

		var len = socklen_t(MemoryLayout<sockaddr_in>.size)

		getsockname(
			socketFD,
			withUnsafeMutablePointer(to: &addr) {
				$0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
					UnsafeMutablePointer($0)
				}
			}, &len)

		return Int(UInt16(bigEndian: addr.sin_port))
	}

	public static func environment(runMode: Utils.RunMode) throws -> [String: String] {
		var environment = ProcessInfo.processInfo.environment
		let home = try Utils.getHome(runMode: runMode)

		environment["TART_HOME"] = home.path

		if environment["CAKE_HOME"] == nil {
			environment["CAKE_HOME"] = home.path
		}

		return environment
	}

	// MARK: - Async helpers
	/// Load raw Data from a URL. If the URL is a file URL, it uses async file IO; otherwise it performs a network request.
	@discardableResult
	public static func loadData(from url: URL, timeout: TimeInterval = 60) async throws -> Data {
		if url.isFileURL {
			// Async file read on a background thread
			return try await withCheckedThrowingContinuation { continuation in
				DispatchQueue.global(qos: .utility).async {
					do {
						let data = try Data(contentsOf: url)
						continuation.resume(returning: data)
					} catch {
						continuation.resume(throwing: error)
					}
				}
			}
		} else {
			var request = URLRequest(url: url)
			request.timeoutInterval = timeout
			let (data, response) = try await URLSession.shared.data(for: request)
			if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
				throw ServiceError("HTTP error: \(http.statusCode) for URL: \(url.absoluteString)")
			}
			return data
		}
	}

	/// Decode JSON from a URL into a Decodable type using `loadData(from:)`.
	public static func loadJSON<T: Decodable>(from url: URL, as type: T.Type = T.self, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
		let data = try await loadData(from: url)
		do {
			return try decoder.decode(T.self, from: data)
		} catch {
			throw ServiceError("JSON decode failed for URL: \(url.absoluteString) with error: \(error)")
		}
	}
}

extension Thread {
	public static var currentThread: Thread {
		Thread.current
	}
}
