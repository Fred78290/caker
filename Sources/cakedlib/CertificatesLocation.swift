import Foundation
import GRPCLib

public struct CertificatesLocation: Codable {
	public let certHome: URL
	public let caCertURL: URL
	public let caKeyURL: URL
	public let clientKeyURL: URL
	public let clientCertURL: URL
	public let serverKeyURL: URL
	public let serverCertURL: URL

	public var files: [URL] {
		[
			self.caCertURL,
			self.caKeyURL,
			self.clientKeyURL,
			self.clientCertURL,
			self.serverKeyURL,
			self.serverCertURL,
		]
	}

	public init(certHome: URL) {
		self.certHome = certHome
		self.caCertURL = URL(fileURLWithPath: "ca.pem", relativeTo: certHome).absoluteURL
		self.caKeyURL = URL(fileURLWithPath: "ca.key", relativeTo: certHome).absoluteURL
		self.clientKeyURL = URL(fileURLWithPath: "client.key", relativeTo: certHome).absoluteURL
		self.clientCertURL = URL(fileURLWithPath: "client.pem", relativeTo: certHome).absoluteURL
		self.serverKeyURL = URL(fileURLWithPath: "server.key", relativeTo: certHome).absoluteURL
		self.serverCertURL = URL(fileURLWithPath: "server.pem", relativeTo: certHome).absoluteURL
	}

	public func createCertificats(subject: String, numberOfYears: Int = 10, _ force: Bool = false) throws -> CertificatesLocation {
		if force || FileManager.default.fileExists(atPath: self.serverKeyURL.path) == false {
			try FileManager.default.createDirectory(at: self.certHome, withIntermediateDirectories: true)
			try RSAKeyGenerator.generateClientServerCertificate(
				subject: subject, numberOfYears: numberOfYears,
				caKeyURL: self.caKeyURL, caCertURL: self.caCertURL,
				serverKeyURL: self.serverKeyURL, serverCertURL: self.serverCertURL,
				clientKeyURL: self.clientKeyURL, clientCertURL: self.clientCertURL)
		}

		return self
	}

	public static func getCertificats(runMode: Utils.RunMode) throws -> CertificatesLocation {
		return CertificatesLocation(certHome: URL(fileURLWithPath: "certs", isDirectory: true, relativeTo: try Utils.getHome(runMode: runMode)))
	}

	public static func createCertificats(runMode: Utils.RunMode, force: Bool = false) throws -> CertificatesLocation {
		let certs: CertificatesLocation = try getCertificats(runMode: runMode)

		return try certs.createCertificats(subject: "Caker", force)
	}

	public static func createAgentCertificats(runMode: Utils.RunMode, force: Bool = false) throws -> CertificatesLocation {
		let certs: CertificatesLocation = CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(runMode: runMode)))

		return try certs.createCertificats(subject: "CakeAgent", force)
	}
}
