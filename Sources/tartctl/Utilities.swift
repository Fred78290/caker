import Foundation

let tartHelperSignature = "com.aldunelabs.tarthelper"

struct Utils {
	static func getTartHome(asSystem: Bool = false) throws -> URL {
		let tartHomeDir: URL

		if asSystem {
			let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .systemDomainMask, true)
			var applicationSupportDirectory = URL(fileURLWithPath: paths.first!, isDirectory: true)

			applicationSupportDirectory = URL(fileURLWithPath: tartHelperSignature,
			                                  isDirectory: true,
			                                  relativeTo: applicationSupportDirectory)
			try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)

			tartHomeDir = applicationSupportDirectory
		} else if let customTartHome = ProcessInfo.processInfo.environment["TARTHELPER_HOME"] {
			tartHomeDir = URL(fileURLWithPath: customTartHome)
		} else if let customTartHome = ProcessInfo.processInfo.environment["TART_HOME"] {
			tartHomeDir = URL(fileURLWithPath: customTartHome)
		} else {
			tartHomeDir = FileManager.default
				.homeDirectoryForCurrentUser
				.appendingPathComponent(".tart", isDirectory: true)
		}

		try FileManager.default.createDirectory(at: tartHomeDir, withIntermediateDirectories: true)

		return tartHomeDir
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
		return CertificatesLocation(certHome: URL(fileURLWithPath: "certs", isDirectory: true, relativeTo: try Utils.getTartHome(asSystem: asSystem)))
	}

	func exists() -> Bool {
		return FileManager.default.fileExists(atPath: self.clientKeyURL.path()) && FileManager.default.fileExists(atPath: self.clientCertURL.path())
	}
}
