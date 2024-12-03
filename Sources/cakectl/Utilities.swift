import Foundation
import GRPCLib

struct ClientCertificatesLocation: Codable {
	let caCertURL: URL
	let clientKeyURL: URL
	let clientCertURL: URL

	init(certHome: URL) {
		self.caCertURL = URL(fileURLWithPath: "ca.pem", relativeTo: certHome).absoluteURL
		self.clientKeyURL = URL(fileURLWithPath: "client.key", relativeTo: certHome).absoluteURL
		self.clientCertURL = URL(fileURLWithPath: "client.pem", relativeTo: certHome).absoluteURL
	}

	static func getCertificats(asSystem: Bool) throws -> ClientCertificatesLocation {
		return ClientCertificatesLocation(certHome: URL(fileURLWithPath: "certs", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem)))
	}

	func exists() -> Bool {
		return FileManager.default.fileExists(atPath: self.clientKeyURL.path()) && FileManager.default.fileExists(atPath: self.clientCertURL.path())
	}
}
