import Foundation

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
		if asSystem {
			let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .systemDomainMask, true)
			var applicationSupportDirectory = URL(fileURLWithPath: paths.first!, isDirectory: true)

			applicationSupportDirectory = URL(fileURLWithPath: tartDSignature,
											  isDirectory: true,
											  relativeTo: applicationSupportDirectory)
			try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)

			return applicationSupportDirectory
		}

		return try Config().tartHomeDir
	}

	static func getOutputLog(asSystem: Bool) -> String {
		if asSystem {
			return "/Library/Logs/tartd.log"
		}

		return URL(fileURLWithPath: "tartd.log", relativeTo: try? Config().tartHomeDir).absoluteURL.path()
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