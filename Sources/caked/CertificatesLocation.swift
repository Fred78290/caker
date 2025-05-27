import Foundation
import GRPCLib

struct CertificatesLocation: Codable {
	let certHome: URL
	let caCertURL: URL
	let caKeyURL: URL
	let clientKeyURL: URL
	let clientCertURL: URL
	let serverKeyURL: URL
	let serverCertURL: URL

	var files: [URL] {
		[
			self.caCertURL,
			self.caKeyURL,
			self.clientKeyURL,
			self.clientCertURL,
			self.serverKeyURL,
			self.serverCertURL
		]
	}

	init(certHome: URL) {
		self.certHome = certHome
		self.caCertURL = URL(fileURLWithPath: "ca.pem", relativeTo: certHome).absoluteURL
		self.caKeyURL = URL(fileURLWithPath: "ca.key", relativeTo: certHome).absoluteURL
		self.clientKeyURL = URL(fileURLWithPath: "client.key", relativeTo: certHome).absoluteURL
		self.clientCertURL = URL(fileURLWithPath: "client.pem", relativeTo: certHome).absoluteURL
		self.serverKeyURL = URL(fileURLWithPath: "server.key", relativeTo: certHome).absoluteURL
		self.serverCertURL = URL(fileURLWithPath: "server.pem", relativeTo: certHome).absoluteURL
	}

	func createCertificats(subject: String, numberOfYears: Int = 10, _ force: Bool = false) throws -> CertificatesLocation {
		if force || FileManager.default.fileExists(atPath: self.serverKeyURL.path) == false {
			try FileManager.default.createDirectory(at: self.certHome, withIntermediateDirectories: true)
			try RSAKeyGenerator.generateClientServerCertificate(subject: subject, numberOfYears: numberOfYears,
			                                                    caKeyURL: self.caKeyURL, caCertURL: self.caCertURL,
			                                                    serverKeyURL: self.serverKeyURL, serverCertURL: self.serverCertURL,
			                                                    clientKeyURL: self.clientKeyURL, clientCertURL: self.clientCertURL)
		}

		return self
	}

	static func getCertificats(asSystem: Bool) throws -> CertificatesLocation {
		return CertificatesLocation(certHome: URL(fileURLWithPath: "certs", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem)))
	}

	static func createCertificats(asSystem: Bool, force: Bool = false) throws -> CertificatesLocation {
		let certs: CertificatesLocation = try getCertificats(asSystem: asSystem)

		return try certs.createCertificats(subject: "Caker", force)
	}

	static func createAgentCertificats(asSystem: Bool, force: Bool = false) throws -> CertificatesLocation {
		let certs: CertificatesLocation = CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem)))

		return try certs.createCertificats(subject: "CakeAgent", force)
	}
}

