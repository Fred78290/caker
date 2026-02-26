import ArgumentParser
import CakedLib
import CakeAgentLib
import Crypto
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import NIOSSL
import Security
import SwiftASN1
import Synchronization
import X509

struct Certs {
	let ca: String?
	let key: String?
	let cert: String?
}

struct Service: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "caked as launchctl agent",
		subcommands: [Install.self, Listen.self, Show.self])
}

extension Service {
	struct ServiceOptions: ParsableArguments {
		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logger.LogLevel = .info

		@Flag(name: [.customLong("system"), .customShort("s")], help: "Install caked as system agent, need sudo")
		var asSystem: Bool = false

		@Option(name: [.customLong("address"), .customShort("l")], help: "Listen on address")
		var address: [String] = []

		@Flag(name: [.customLong("insecure"), .customShort("i")], help: "don't use TLS")
		var insecure: Bool = false

		@Option(name: [.customLong("ca-cert"), .customShort("c")], help: "CA TLS certificate")
		var caCert: String?

		@Option(name: [.customLong("tls-cert"), .customShort("t")], help: "Client TLS certificate")
		var tlsCert: String?

		@Option(name: [.customLong("tls-key"), .customShort("k")], help: "Client private key")
		var tlsKey: String?

		@Flag(help: ArgumentHelp("Service endpoint", discussion: "This option allow mode to connect to a VMRun service endpoint"))
		var mode: VMRunServiceMode = .grpc

		var runMode: Utils.RunMode {
			self.asSystem ? .system : .user
		}

		func validate() throws {
			Logger.setLevel(self.logLevel)

			VMRunHandler.serviceMode = mode

			if self.insecure == false {
				if let caCert, let tlsCert, let tlsKey {
					if FileManager.default.fileExists(atPath: caCert) == false {
						throw ServiceError("Root certificate file not found: \(caCert)")
					}

					if FileManager.default.fileExists(atPath: tlsCert) == false {
						throw ServiceError("TLS certificate file not found: \(tlsCert)")
					}

					if FileManager.default.fileExists(atPath: tlsKey) == false {
						throw ServiceError("TLS key file not found: \(tlsKey)")
					}
				}
			}
		}

		func getCertificats() throws -> Certs {
			if self.tlsCert == nil && self.tlsKey == nil {
				let certs = try CertificatesLocation.createCertificats(runMode: self.asSystem ? .system : .user)

				return Certs(ca: certs.caCertURL.path, key: certs.serverKeyURL.path, cert: certs.serverCertURL.path)
			}

			return Certs(ca: self.caCert, key: self.tlsKey, cert: self.tlsCert)
		}

		func getListenAddress() throws -> [String] {
			if self.address.isEmpty {
				return [try Utils.getDefaultServerAddress(runMode: self.asSystem ? .system : .user)]
			}

			return address
		}
	}

	struct Install: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Install caked daemon as launchctl agent")

		@OptionGroup(title: "Agent common options")
		var options: ServiceOptions

		func run() throws {
			let runMode: Utils.RunMode = self.options.runMode
			let listenAddress = try self.options.getListenAddress()

			var caCert: String? = nil
			var tlsCert: String? = nil
			var tlsKey: String? = nil

			if self.options.insecure == false {
				let certs = try self.options.getCertificats()

				caCert = certs.ca
				tlsKey = certs.key
				tlsCert = certs.cert
			}

			try ServiceHandler.installAgent(listenAddress: listenAddress, insecure: self.options.insecure, caCert: caCert, tlsCert: tlsCert, tlsKey: tlsKey, runMode: runMode)
		}
	}

	struct Listen: AsyncParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: "caked daemon listening")

		@Flag(help: .hidden)
		var secure: Bool = false

		@OptionGroup(title: "Agent common options")
		var options: ServiceOptions

		mutating func validate() throws {
			let runMode: Utils.RunMode = self.options.runMode

			if self.secure {
				let certs = try CertificatesLocation.createCertificats(runMode: runMode)

				self.options.caCert = certs.caCertURL.path
				self.options.tlsCert = certs.serverCertURL.path
				self.options.tlsKey = certs.serverKeyURL.path
			} else if let caCert = self.options.caCert, let tlsCert = self.options.tlsCert, let tlsKey = self.options.tlsKey {
				if FileManager.default.fileExists(atPath: caCert) == false {
					throw ServiceError("Root certificate file not found: \(caCert)")
				}

				if FileManager.default.fileExists(atPath: tlsCert) == false {
					throw ServiceError("TLS certificate file not found: \(tlsCert)")
				}

				if FileManager.default.fileExists(atPath: tlsKey) == false {
					throw ServiceError("TLS key file not found: \(tlsKey)")
				}
			} else if (self.options.tlsKey != nil || self.options.tlsCert != nil) && (self.options.tlsKey == nil || self.options.tlsCert == nil) {
				throw ServiceError("Some cert files not provided")
			}
		}

		func run() async throws {
			let listenAddress = try self.options.getListenAddress()
			
			guard listenAddress.count > 0 else {
				throw ServiceError("No listen address provided")
			}

			let runMode: Utils.RunMode = self.options.runMode
			let home = try Home(runMode: runMode)

			try home.agentPID.writePID()

			defer {
				try? home.agentPID.delete()
			}

			try CakedLib.StartHandler.autostart(on: Utilities.group.next(), runMode: runMode)

			let eventLoopGroup = Utilities.group
			let servers: [Server] = try listenAddress.map { address in
				Logger(self).info("Start listening on \(address)")
				return try ServiceHandler.createServer(
					eventLoopGroup: eventLoopGroup,
					runMode: runMode,
					listeningAddress: URL(string: address),
					serviceProviders: [try CakedProvider(group: eventLoopGroup, runMode: runMode)],
					caCert: self.options.caCert,
					tlsCert: self.options.tlsCert,
					tlsKey: self.options.tlsKey
				).wait()
			}

			Root.sigintSrc.cancel()

			signal(SIGINT, SIG_IGN)

			let sigintSrc: any DispatchSourceSignal = DispatchSource.makeSignalSource(signal: SIGINT)

			sigintSrc.setEventHandler {
				servers.forEach {
					try? $0.close().wait()
				}
			}

			sigintSrc.activate()

			// Wait on the server's `onClose` future to stop the program from exiting.
			if servers.count > 1 {
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

	struct Show: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Help to run caked daemon")

		@OptionGroup(title: "Agent common options")
		var options: ServiceOptions

		mutating func run() throws {
			let listenAddress = try self.options.getListenAddress()

			var arguments: [String] = [
				try ServiceHandler.findMe(),
				"service",
				"listen",
				"--log-level=\(self.options.logLevel.rawValue)",
			]

			listenAddress.forEach {
				arguments.append("--address=\($0)")
			}

			if self.options.asSystem {
				arguments.append("--system")
			}

			if self.options.insecure == false {
				let certs = try self.options.getCertificats()

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

			Logger.appendNewLine(arguments.joined(separator: " "))
		}
	}
}
