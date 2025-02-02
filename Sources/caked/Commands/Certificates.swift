
import ArgumentParser
import Foundation
import GRPCLib
import Logging
import TextTable

struct Certificates: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Generate tls certificates for grpc",
													subcommands: [Generate.self, Get.self])

	struct Get: ParsableCommand {
		static var configuration = CommandConfiguration(abstract: "Return certificates path")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: [.customLong("global"), .customShort("g")], help: "Install agent globally, need sudo")
		var asSystem: Bool = false

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		mutating func run() throws {
			let format: Format = .text

			print(format.renderSingle(style: Style.grid, uppercased: true, try CertificatesLocation.getCertificats(asSystem: asSystem)))
		}
	}

	struct Generate: ParsableCommand {
		static var configuration = CommandConfiguration(abstract: "Generate certificates")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: [.customLong("global"), .customShort("g")], help: "Install agent globally, need sudo")
		var asSystem: Bool = false

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		mutating func run() throws {
			let format: Format = .text

			print(format.renderSingle(style: Style.grid, uppercased: true, try CertificatesLocation.createCertificats(asSystem: asSystem)))
		}
	}
}
