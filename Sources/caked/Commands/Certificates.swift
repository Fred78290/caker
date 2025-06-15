import ArgumentParser
import Foundation
import GRPCLib
import Logging
import TextTable
import CakedLib


extension Format {
	func render(_ data: CertificatesLocation) -> String {
		switch self {
		case .json:
			return self.renderSingle(data)
		case .text:
			return self.renderSingle(data.flatMap())
		}
	}
}

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
	static let configuration = CommandConfiguration(
		abstract: "Generate tls certificates for grpc",
		subcommands: [Generate.self, Get.self, Agent.self])

	struct Get: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Return certificates path")

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try CertificatesLocation.getCertificats(runMode: self.common.runMode)))
		}
	}

	struct Generate: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Generate certificates")

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@Flag(name: .shortAndLong, help: "Force regeneration of certificates")
		var force: Bool = false

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try CertificatesLocation.createCertificats(runMode: self.common.runMode, force: self.force)))
		}
	}

	struct Agent: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Generate certificates for cakeagent")

		@OptionGroup(title: "Global options")
		var common: CommonOptions

		@Flag(name: .shortAndLong, help: "Force regeneration of certificates")
		var force: Bool = false

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(try CertificatesLocation.createAgentCertificats(runMode: self.common.runMode, force: self.force)))
		}
	}
}
