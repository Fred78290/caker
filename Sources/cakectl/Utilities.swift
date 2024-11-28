import Foundation

let cakerSignature = "com.aldunelabs.caker"

struct Utils {
	static func getHome(asSystem: Bool = false) throws -> URL {
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
		} else if let customHome = ProcessInfo.processInfo.environment["TART_HOME"] {
			cakeHomeDir = URL(fileURLWithPath: customHome)
		} else {
			cakeHomeDir = FileManager.default
				.homeDirectoryForCurrentUser
				.appendingPathComponent(".tart", isDirectory: true)
		}

		try FileManager.default.createDirectory(at: cakeHomeDir, withIntermediateDirectories: true)

		return cakeHomeDir
	}

}

struct CertificatesLocation: Codable {
	let caCertURL: URL
	let clientKeyURL: URL
	let clientCertURL: URL

	init(certHome: URL) {
		self.caCertURL = URL(fileURLWithPath: "ca.pem", relativeTo: certHome).absoluteURL
		self.clientKeyURL = URL(fileURLWithPath: "client.key", relativeTo: certHome).absoluteURL
		self.clientCertURL = URL(fileURLWithPath: "client.pem", relativeTo: certHome).absoluteURL
	}

	static func getCertificats(asSystem: Bool) throws -> CertificatesLocation {
		return CertificatesLocation(certHome: URL(fileURLWithPath: "certs", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem)))
	}

	func exists() -> Bool {
		return FileManager.default.fileExists(atPath: self.clientKeyURL.path()) && FileManager.default.fileExists(atPath: self.clientCertURL.path())
	}
}
