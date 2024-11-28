import Foundation

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

	static func getCertificats(asSystem: Bool) throws -> CertificatesLocation {
		return CertificatesLocation(certHome: URL(fileURLWithPath: "certs", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem)))
	}

	static func createCertificats(asSystem: Bool) throws -> CertificatesLocation {
		let certs: CertificatesLocation = try getCertificats(asSystem: asSystem)

		if FileManager.default.fileExists(atPath: certs.serverKeyURL.path()) == false {
			try FileManager.default.createDirectory(at: certs.certHome, withIntermediateDirectories: true)
			try CypherKeyGenerator.generateClientServerCertificate(subject: "Caker", numberOfYears: 1,
																caKeyURL: certs.caKeyURL, caCertURL: certs.caCertURL,
																serverKeyURL: certs.serverKeyURL, serverCertURL: certs.serverCertURL,
																clientKeyURL: certs.clientKeyURL, clientCertURL: certs.clientCertURL)
		}

		return certs
	}
}

