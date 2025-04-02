
import ArgumentParser
import Foundation
import GRPCLib
import Logging
import TextTable

extension CertificatesLocation {
	struct CertAsText: Codable {
		let type: String
		let path: String
		let created: Date
	}

	func flatMap() -> [CertAsText] {
		var out: [CertAsText] = []

		out.append(CertAsText(type: "caCertURL", path: self.caCertURL.path, created: try! self.caCertURL.resourceValues(forKeys: [.creationDateKey]).creationDate!))
		out.append(CertAsText(type: "caKeyURL", path: self.caKeyURL.path, created: try! self.caKeyURL.resourceValues(forKeys: [.creationDateKey]).creationDate!))
		out.append(CertAsText(type: "clientKeyURL", path: self.clientKeyURL.path, created: try! self.clientKeyURL.resourceValues(forKeys: [.creationDateKey]).creationDate!))
		out.append(CertAsText(type: "clientCertURL", path: self.clientCertURL.path, created: try! self.clientCertURL.resourceValues(forKeys: [.creationDateKey]).creationDate!))
		out.append(CertAsText(type: "serverKeyURL", path: self.serverKeyURL.path, created: try! self.serverKeyURL.resourceValues(forKeys: [.creationDateKey]).creationDate!))
		out.append(CertAsText(type: "serverCertURL", path: self.serverCertURL.path, created: try! self.serverCertURL.resourceValues(forKeys: [.creationDateKey]).creationDate!))

		return out
	}
}

struct Certificates: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Generate tls certificates for grpc",
													subcommands: [Generate.self, Get.self, Agent.self])

	struct Get: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Return certificates path")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: [.customLong("global"), .customShort("g")], help: "Install agent globally, need sudo")
		var asSystem: Bool = false

		func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		func run() throws {
			let format: Format = .text

			print(format.renderSingle(style: Style.grid, uppercased: true, try CertificatesLocation.getCertificats(asSystem: asSystem)))
		}
	}

	struct Generate: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Generate certificates")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: [.customLong("global"), .customShort("g")], help: "Install agent globally, need sudo")
		var asSystem: Bool = false

		@Flag(name: .shortAndLong, help: "Force regeneration of certificates")
		var force: Bool = false

		func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		func run() throws {
			let format: Format = .text
			let certs = try CertificatesLocation.createCertificats(asSystem: asSystem, force: self.force)

			if format == .json {
				print(format.renderSingle(style: Style.grid, uppercased: true, certs))
			} else {
				print(format.renderList(style: Style.grid, uppercased: true, certs.flatMap()))
			}
		}
	}

	struct Agent: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Generate certificates for cakeagent")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: [.customLong("global"), .customShort("g")], help: "Install agent globally, need sudo")
		var asSystem: Bool = false

		@Flag(name: .shortAndLong, help: "Force regeneration of certificates")
		var force: Bool = false

		func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		func run() throws {
			let format: Format = .text
			let certs = try CertificatesLocation.createAgentCertificats(asSystem: runAsSystem, force: self.force)

			if format == .json {
				print(format.renderSingle(style: Style.grid, uppercased: true, certs))
			} else {
				print(format.renderList(style: Style.grid, uppercased: true, certs.flatMap()))
			}
		}
	}
}
