import ArgumentParser
import Foundation
import ShellOut
import GRPC
import NIOSSL
import NIOCore
import NIOPosix
import Synchronization
import Crypto
import SwiftASN1
import X509
import Security

let tartHelperSignature = "com.aldunelabs.tarthelper"

class ServiceError : Error, CustomStringConvertible {
	let description: String

	init(_ what: String) {
		self.description = what
	}
}

struct Certs {
	let ca: String?
	let key: String?
	let cert: String?
}

struct Service: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Tart helper as launchctl agent",
	                                                subcommands: [Install.self, Listen.self])
	static let SyncSemaphore = DispatchSemaphore(value: 0)

}

extension Service {
	struct LaunchAgent: Codable {
		let label: String
		let programArguments: [String]
		let keepAlive: [String:Bool]
		let runAtLoad: Bool
		let abandonProcessGroup: Bool
		let softResourceLimits: [String:Int]
		let environmentVariables: [String:String]
		let standardErrorPath: String
		let standardOutPath: String
		let processType: String

		enum CodingKeys: String, CodingKey {
			case label = "Label"
			case programArguments = "ProgramArguments"
			case keepAlive = "KeepAlive"
			case runAtLoad = "RunAtLoad"
			case abandonProcessGroup = "AbandonProcessGroup"
			case softResourceLimits = "SoftResourceLimits"
			case environmentVariables = "EnvironmentVariables"
			case standardErrorPath = "StandardErrorPath"
			case standardOutPath = "StandardOutPath"
			case processType = "ProcessType"
		}

		func write(to: URL) throws {
			let encoder = PropertyListEncoder()
			encoder.outputFormat = .xml

			let data = try encoder.encode(self)
			try data.write(to: to)
		}
	}
	struct Install : ParsableCommand {    
		static var configuration = CommandConfiguration(abstract: "Install tart daemon as launchctl agent")

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Install TartHelper as system agent, need sudo")
		var asSystem: Bool = false

		@Option(name: [.customLong("address"), .customShort("l")], help: "Listen on address")
		var address: String?

		@Flag(name: [.customLong("insecure"), .customShort("k")], help: "don't use TLS")
		var insecure: Bool = false

		@Option(name: [.customLong("ca-cert"), .customShort("c")], help: "CA TLS certificate")
		var caCert: String?

		@Option(name: [.customLong("tls-cert"), .customShort("t")], help: "Client TLS certificate")
		var tlsCert: String?

		@Option(name: [.customLong("tls-key"), .customShort("k")], help: "Client private key")
		var tlsKey: String?

		static func findMe() throws -> String {
			return try shellOut(to: "command", arguments: ["-v", "tarthelper"])
		}

		func getCertificats() throws -> Certs {
			if self.tlsCert == nil && self.tlsKey == nil {
				let certs = try CertificatesLocation.createCertificats(asSystem: self.asSystem)

				return Certs(ca: certs.caCertURL.path(), key: certs.serverKeyURL.path(), cert: certs.serverCertURL.path())
			}

			return Certs(ca: self.caCert, key: self.tlsKey, cert: self.tlsCert)
		}

		func getListenAddress() throws -> String {
			if let address = self.address {
				return address
			}

			return try Utils.getListenAddress(asSystem: self.asSystem)
		}

		mutating func run() throws {
			runAsSystem = self.asSystem

			let listenAddress: String = try getListenAddress()
			let outputLog: String = Utils.getOutputLog(asSystem: self.asSystem)
			let tartHome: URL = try Utils.getTartHome(asSystem: self.asSystem)

			var arguments: [String] = [
				try Install.findMe(),
				"listen",
				"--address=\(listenAddress)"
			]

			if asSystem {
				arguments.append("--system")
			}

			if self.insecure == false {
				let certs = try getCertificats()

				if let ca = certs.ca {
					arguments.append("--ca-cert=\(ca)")
				}

				if let key = certs.key {
					arguments.append("--tls-cert=\(key)")
				}

				if let cert = certs.cert {
					arguments.append("--tls-key=\(cert)")
				}
			}

			let agent = LaunchAgent(label: tartHelperSignature,
			                        programArguments: arguments,
			                        keepAlive: [
			                        	"SuccessfulExit" : false
			                        ],
			                        runAtLoad: true,
			                        abandonProcessGroup: true,
			                        softResourceLimits: [
			                        	"NumberOfFiles" : 4096
			                        ],
			                        environmentVariables: [
			                        	"PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin/:/sbin",
			                        	"TART_HOME" : tartHome.path()
			                        ],
			                        standardErrorPath: outputLog,
			                        standardOutPath: outputLog,
			                        processType: "Background")

			let agentURL: URL

			if self.asSystem {
				agentURL = URL(fileURLWithPath: "/Library/LaunchDaemons/\(tartHelperSignature).plist")
			} else {
				agentURL = URL(fileURLWithPath: "\(NSHomeDirectory())/Library/LaunchAgents/\(tartHelperSignature).plist")
			}

			try agent.write(to: agentURL)
		}
	}

	struct Listen : ParsableCommand {
		static var configuration = CommandConfiguration(abstract: "tart daemon listening")

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Run TartHelper as system agent, need sudo")
		var asSystem: Bool = false

		@Option(name: [.customLong("address"), .customShort("l")], help: "Listen on address")
		var address: String?

		@Option(name: [.customLong("ca-cert"), .customShort("c")], help: "CA TLS certificate")
		var caCert: String?

		@Option(name: [.customLong("tls-cert"), .customShort("t")], help: "Server TLS certificate")
		var tlsCert: String?

		@Option(name: [.customLong("tls-key"), .customShort("k")], help: "Server private key")
		var tlsKey: String?

		func validate() throws {
			if let caCert = self.caCert, let tlsCert = self.tlsCert, let tlsKey = self.tlsKey {
				if FileManager.default.fileExists(atPath: caCert) == false {
					throw ServiceError("Root certificate file not found: \(caCert)")
				}

				if FileManager.default.fileExists(atPath: tlsCert) == false {
					throw ServiceError("TLS certificate file not found: \(tlsCert)")
				}

				if FileManager.default.fileExists(atPath: tlsKey) == false {
					throw ServiceError("TLS key file not found: \(tlsKey)")
				}
			} else if (self.tlsKey != nil || self.tlsCert != nil) && (self.tlsKey == nil || self.tlsCert == nil) {
				throw ServiceError("Some cert files not provided")
			}
		}

		private func getServerAddress() throws -> String {
			if let address = self.address {
				return address
			} else {
				return try Utils.getListenAddress(asSystem: asSystem)
			}
		}

		static func createServer(on: MultiThreadedEventLoopGroup,
		                         asSystem: Bool,
		                         listeningAddress: URL?,
		                         caCert: String?,
		                         tlsCert: String?,
		                         tlsKey: String?) throws -> EventLoopFuture<Server> {
			if let listeningAddress = listeningAddress {
				let target: ConnectionTarget

				if listeningAddress.scheme == "unix" {
					target = ConnectionTarget.unixDomainSocket(listeningAddress.path())
				} else if listeningAddress.scheme == "tcp" {
					target = ConnectionTarget.hostAndPort(listeningAddress.host ?? "127.0.0.1", listeningAddress.port ?? 5000)
				} else {
					throw ServiceError("unsupported listening address scheme: \(String(describing: listeningAddress.scheme))")
				}

				var serverConfiguration = Server.Configuration.default(target: target,
				                                                       eventLoopGroup: on,
				                                                       serviceProviders: [TartDaemonProvider(asSystem: asSystem)])

				if let tlsCert = tlsCert, let tlsKey = tlsKey {
					let tlsCert = try NIOSSLCertificate(file: tlsCert, format: .pem)
					let tlsKey = try NIOSSLPrivateKey(file: tlsKey, format: .pem)
					let trustRoots: NIOSSLTrustRoots

					if let caCert: String = caCert {
						trustRoots = .certificates([try NIOSSLCertificate(file: caCert, format: .pem)])
					} else {
						trustRoots = NIOSSLTrustRoots.default
					}

					serverConfiguration.tlsConfiguration = GRPCTLSConfiguration.makeServerConfigurationBackedByNIOSSL(
						certificateChain: [.certificate(tlsCert)],
						privateKey: .privateKey(tlsKey),
						trustRoots: trustRoots,
						certificateVerification: CertificateVerification.none,
						requireALPN: false)
				}

				return Server.start(configuration: serverConfiguration)
			}

			throw ServiceError("connection address must be specified")
		}

		mutating func run() throws {
			runAsSystem = self.asSystem

			let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

			defer {
				try! group.syncShutdownGracefully()
			}

			// Start the server and print its address once it has started.
			let server = try Self.createServer(on: group,
			                                   asSystem: self.asSystem,
			                                   listeningAddress: URL(string: try self.getServerAddress()),
			                                   caCert: self.caCert,
			                                   tlsCert: self.tlsCert,
			                                   tlsKey: self.tlsKey).wait()

			// Wait on the server's `onClose` future to stop the program from exiting.
			try server.onClose.wait()
		}
	}
}
