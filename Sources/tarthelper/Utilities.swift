import Foundation
import System

struct Utils {
	struct CertificatesLocation: Codable {
		let certHome: URL
		let caCertURL: URL
		let caKeyURL: URL
		let clientKeyURL: URL
		let clientCertURL: URL
		let serverKeyURL: URL
		let serverCertURL: URL

		init(certHome: URL) {
			self.certHome = certHome
			self.caCertURL = URL(fileURLWithPath: "ca.pem", relativeTo: certHome).absoluteURL
			self.caKeyURL = URL(fileURLWithPath: "ca.key", relativeTo: certHome).absoluteURL
			self.clientKeyURL = URL(fileURLWithPath: "client.key", relativeTo: certHome).absoluteURL
			self.clientCertURL = URL(fileURLWithPath: "client.pem", relativeTo: certHome).absoluteURL
			self.serverKeyURL = URL(fileURLWithPath: "server.key", relativeTo: certHome).absoluteURL
			self.serverCertURL = URL(fileURLWithPath: "server.pem", relativeTo: certHome).absoluteURL
		}
	}

	static func getTartHome(asSystem: Bool) throws -> URL {
		return try Home(asSystem: asSystem).homeDir
	}

	static func getOutputLog(asSystem: Bool) -> String {
		if asSystem {
			return "/Library/Logs/tarthelper.log"
		}

		return URL(fileURLWithPath: "tarthelper.log", relativeTo: try? Home(asSystem: false).homeDir).absoluteURL.path()
	}

	static func getListenAddress(asSystem: Bool) throws -> String {
		if let tartdListenAddress = ProcessInfo.processInfo.environment["TARTD_LISTEN_ADDRESS"] {
			return tartdListenAddress
		} else {
			var home = try Self.getTartHome(asSystem: asSystem)

			home.append(path: "tard.sock")

			return "unix://\(home.absoluteURL.path())"
		}
	}

	static func getCertificats(asSystem: Bool) throws -> CertificatesLocation {
		return CertificatesLocation(certHome: URL(fileURLWithPath: "certs", isDirectory: true, relativeTo: try Utils.getTartHome(asSystem: asSystem)))
	}

	static func createCertificats(asSystem: Bool) throws -> CertificatesLocation {
		let certs: Utils.CertificatesLocation = try getCertificats(asSystem: asSystem)

		if FileManager.default.fileExists(atPath: certs.serverKeyURL.path()) == false {
			try FileManager.default.createDirectory(at: certs.certHome, withIntermediateDirectories: true)
			try CypherKeyGenerator.generateClientServerCertificate(subject: "Tart daemon", numberOfYears: 1,
			                                                       caKeyURL: certs.caKeyURL, caCertURL: certs.caCertURL,
			                                                       serverKeyURL: certs.serverKeyURL, serverCertURL: certs.serverCertURL,
			                                                       clientKeyURL: certs.clientKeyURL, clientCertURL: certs.clientCertURL)
		}

		return certs
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
