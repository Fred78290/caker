import ArgumentParser
import Foundation
import GRPC
import NIOSSL
import NIOCore
import NIOPosix
import Synchronization
import Crypto
import SwiftASN1
import X509
import Security
import GRPCLib
import Logging

protocol HasExitCode {
	var exitCode: Int32 { get }
}


class ServiceError : Error, CustomStringConvertible {
	let description: String
	let exitCode: Int32

	init(_ what: String, _ code: Int32 = 1) {
		self.description = what
		self.exitCode = code
	}
}

struct Certs {
	let ca: String?
	let key: String?
	let cert: String?
}

struct Service: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "caked as launchctl agent",
	                                                subcommands: [Install.self, Listen.self, Show.self])
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
		static var configuration = CommandConfiguration(abstract: "Install caked daemon as launchctl agent")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Install caked as system agent, need sudo")
		var asSystem: Bool = false

		@Option(name: [.customLong("address"), .customShort("l")], help: "Listen on address")
		var address: String?

		@Flag(name: [.customLong("insecure"), .customShort("i")], help: "don't use TLS")
		var insecure: Bool = false

		@Option(name: [.customLong("ca-cert"), .customShort("c")], help: "CA TLS certificate")
		var caCert: String?

		@Option(name: [.customLong("tls-cert"), .customShort("t")], help: "Client TLS certificate")
		var tlsCert: String?

		@Option(name: [.customLong("tls-key"), .customShort("k")], help: "Client private key")
		var tlsKey: String?

		static func findMe() throws -> String {
			return try Shell.execute(to: "command", arguments: ["-v", "caked"])
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

			return try Utils.getDefaultServerAddress(asSystem: self.asSystem)
		}

		func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		func run() throws {
			runAsSystem = self.asSystem

			let listenAddress: String = try getListenAddress()
			let outputLog: String = Utils.getOutputLog(asSystem: self.asSystem)
			let cakeHome: URL = try Utils.getHome(asSystem: self.asSystem)
			let cakedSignature = Utils.cakerSignature

			var arguments: [String] = [
				try Install.findMe(),
				"service",
				"listen",
				"--log-level=\(self.logLevel.rawValue)",
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
					arguments.append("--tls-key=\(key)")
				}

				if let cert = certs.cert {
					arguments.append("--tls-cert=\(cert)")
				}
			}

			let agent = LaunchAgent(label: cakedSignature,
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
			                        	"CAKE_HOME" : cakeHome.path()
			                        ],
			                        standardErrorPath: outputLog,
			                        standardOutPath: outputLog,
			                        processType: "Background")

			let agentURL: URL

			if self.asSystem {
				agentURL = URL(fileURLWithPath: "/Library/LaunchDaemons/\(cakedSignature).plist")
			} else {
				agentURL = URL(fileURLWithPath: "\(NSHomeDirectory())/Library/LaunchAgents/\(cakedSignature).plist")
			}

			try agent.write(to: agentURL)
		}
	}

	struct Listen : AsyncParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(abstract: "tart daemon listening")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Flag(help: .hidden)
		var secure: Bool = false

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Run caked as system agent, need sudo")
		var asSystem: Bool = false

		@Option(name: [.customLong("address"), .customShort("l")], help: "Listen on address")
		var address: [String] = []

		@Option(name: [.customLong("ca-cert"), .customShort("c")], help: "CA TLS certificate")
		var caCert: String?

		@Option(name: [.customLong("tls-cert"), .customShort("t")], help: "Server TLS certificate")
		var tlsCert: String?

		@Option(name: [.customLong("tls-key"), .customShort("k")], help: "Server private key")
		var tlsKey: String?

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)

			if self.secure {
				let certs = try CertificatesLocation.createCertificats(asSystem: self.asSystem)

				self.caCert = certs.caCertURL.path()
				self.tlsCert = certs.serverCertURL.path()
				self.tlsKey = certs.serverKeyURL.path()
			} else if let caCert = self.caCert, let tlsCert = self.tlsCert, let tlsKey = self.tlsKey {
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

		private func getServerAddress() throws -> [String] {
			if self.address.isEmpty {
				return try [Utils.getDefaultServerAddress(asSystem: asSystem)]
			} else {
				return self.address
			}
		}

		static func createServer(eventLoopGroup: EventLoopGroup,
		                         asSystem: Bool,
		                         listeningAddress: URL?,
		                         caCert: String?,
		                         tlsCert: String?,
		                         tlsKey: String?) throws -> EventLoopFuture<Server> {

			if let listeningAddress = listeningAddress {
				let target: ConnectionTarget

				if listeningAddress.isFileURL || listeningAddress.scheme == "unix" {
					try listeningAddress.deleteIfFileExists()
					target = ConnectionTarget.unixDomainSocket(listeningAddress.path())
				} else if listeningAddress.scheme == "tcp" {
					target = ConnectionTarget.hostAndPort(listeningAddress.host ?? "127.0.0.1", listeningAddress.port ?? 5000)
				} else {
					throw ServiceError("unsupported listening address scheme: \(String(describing: listeningAddress.scheme))")
				}

				var serverConfiguration = Server.Configuration.default(target: target,
				                                                       eventLoopGroup: eventLoopGroup,
				                                                       serviceProviders: [try CakedProvider(group: eventLoopGroup, asSystem: asSystem)])

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

		func run() async throws {
			runAsSystem = self.asSystem

			if Root.vmrunAvailable() == false {
				PortForwardingServer.createPortForwardingServer(group: Root.group)
			}

			try StartHandler.autostart(on: Root.group.next(), asSystem: self.asSystem)

			let listenAddress = try self.getServerAddress()

			let servers: [Server] = try listenAddress.map { address in
				Logger(self).info("Start listening on \(address)")
				return try Self.createServer(eventLoopGroup: Root.group,
				                             asSystem: self.asSystem,
				                             listeningAddress: URL(string: address),
				                             caCert: self.caCert,
				                             tlsCert: self.tlsCert,
				                             tlsKey: self.tlsKey).wait()
			}

			signal(SIGINT, SIG_IGN)

			let sigintSrc: any DispatchSourceSignal = DispatchSource.makeSignalSource(signal: SIGINT)

			sigintSrc.setEventHandler {
				servers.forEach {
					try? $0.close().wait()
				}
			}

			sigintSrc.activate()

			// Wait on the server's `onClose` future to stop the program from exiting.
			if servers.count > 0 {
				try await withThrowingTaskGroup(of: Void.self, returning: Void.self) { group in
					servers.forEach { server in
						group.addTask {
							try await server.onClose.get()
						}
					}

					try await group.waitForAll()
				}
			} else {
				try await servers.first!.onClose.get()
			}

			Logger(self).info("Server stopped")
		}
	}

	struct Show : ParsableCommand {    
		static var configuration = CommandConfiguration(abstract: "Help to run caked daemon")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Install caked as system agent, need sudo")
		var asSystem: Bool = false

		@Option(name: [.customLong("address"), .customShort("l")], help: "Listen on address")
		var address: String?

		@Flag(name: [.customLong("insecure"), .customShort("i")], help: "don't use TLS")
		var insecure: Bool = false

		@Option(name: [.customLong("ca-cert"), .customShort("c")], help: "CA TLS certificate")
		var caCert: String?

		@Option(name: [.customLong("tls-cert"), .customShort("t")], help: "Client TLS certificate")
		var tlsCert: String?

		@Option(name: [.customLong("tls-key"), .customShort("k")], help: "Client private key")
		var tlsKey: String?

		static func findMe() throws -> String {
			return try Shell.execute(to: "command", arguments: ["-v", "caked"])
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

			return try Utils.getDefaultServerAddress(asSystem: self.asSystem)
		}

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		mutating func run() throws {
			runAsSystem = self.asSystem

			let listenAddress: String = try getListenAddress()

			var arguments: [String] = [
				try Install.findMe(),
				"service",
				"listen",
				"--log-level=\(self.logLevel.rawValue)",
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
					arguments.append("--tls-key=\(key)")
				}

				if let cert = certs.cert {
					arguments.append("--tls-cert=\(cert)")
				}
			}

			print(arguments.joined(separator: " "))
		}
	}
}
