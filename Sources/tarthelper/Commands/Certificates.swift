
import ArgumentParser
import Foundation

struct Certificates: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Generate tls certificates for grpc",
													subcommands: [Generate.self, Get.self])

	struct Get: ParsableCommand {
		static var configuration = CommandConfiguration(abstract: "Return certificates path")

		@Option(name: [.customLong("global"), .customShort("g")], help: "Install agent globally, need sudo")
		var asSystem: Bool = false

		mutating func run() throws {
			let out = String(data: try! JSONSerialization.data(withJSONObject: try CertificatesLocation.getCertificats(asSystem: asSystem), options: [.prettyPrinted]), encoding: .ascii) ?? ""

			print(out)
		}
	}

	struct Generate: ParsableCommand {
		static var configuration = CommandConfiguration(abstract: "Generate certificates")

		@Option(name: [.customLong("global"), .customShort("g")], help: "Install agent globally, need sudo")
		var asSystem: Bool = false

		mutating func run() throws {
			let out = String(data: try! JSONSerialization.data(withJSONObject: try CertificatesLocation.createCertificats(asSystem: asSystem), options: [.prettyPrinted]), encoding: .ascii) ?? ""

			print(out)
			
		}
	}
}
