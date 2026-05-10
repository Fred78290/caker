import ArgumentParser
import CakeAgentLib
import CakedLib
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
		abstract: String(localized: "caked as launchctl agent"),
		subcommands: [Install.self, Listen.self, Show.self, Status.self, Stop.self])
}

extension Service {
	struct ServiceOptions: ParsableArguments {
		@Option(name: [.customLong("log-level")], help: ArgumentHelp(String(localized: "Log level")))
		var logLevel: Logger.LogLevel = .info

		@Flag(name: [.customLong("system"), .customShort("s")], help: ArgumentHelp(String(localized: "Install caked as system agent, need sudo")))
		var asSystem: Bool = false

		@Option(name: [.customLong("address"), .customShort("l")], help: ArgumentHelp(String(localized: "Listen on address")))
		var address: [String] = []

		@Option(name: [.customLong("pass-phrase")], help: ArgumentHelp(String(localized: "access password"), discussion: String(localized: "This option allows to protect the service endpoint with a password")))
		var password: String? = nil

		@Flag(name: [.customLong("no-pass-phrase")], help: ArgumentHelp(String(localized: "Allow empty password"), discussion: String(localized: "Use this to explicitly set an empty password for the service endpoint")))
		var noPassword: Bool = false

		@Flag(name: [.customLong("insecure"), .customShort("i")], help: ArgumentHelp(String(localized: "Don't use TLS")))
		var insecure: Bool = false

		@Option(name: [.customLong("ca-cert"), .customShort("c")], help: ArgumentHelp(String(localized: "CA TLS certificate")))
		var caCert: String?

		@Option(name: [.customLong("tls-cert"), .customShort("t")], help: ArgumentHelp(String(localized: "Client TLS certificate")))
		var tlsCert: String?

		@Option(name: [.customLong("tls-key"), .customShort("k")], help: ArgumentHelp(String(localized: "Client private key")))
		var tlsKey: String?

		@Flag(help: ArgumentHelp(String(localized: "Service endpoint"), discussion: String(localized: "This option allows mode to connect to a VMRun service endpoint")))
		var mode: VMRunServiceMode = .grpc

		@Flag(help: ArgumentHelp(String(localized: "Use inet socket"), visibility: .hidden))
		var tcp: Bool = false

		@Flag(help: ArgumentHelp(String(localized: "Allows LXD to connect to this host"), visibility: .hidden))
		var rest: Bool = false

		@Option(name: [.customLong("rest-port")], help: ArgumentHelp(String(localized: "Override LXD REST API listen port"), discussion: "By default LXD will listen on 8443 for https and 8080 for http"))
		var restPort: Int = 0

		@Option(name: [.customLong("web-ui")], help: ArgumentHelp(String(localized: "Path to web UI static files directory"), discussion: "When provided, caked serves the web UI under /ui"))
		var webUIDirectory: String? = nil

		var runMode: Utils.RunMode {
			self.asSystem ? .system : .user
		}

		func validate() throws {
			Logger.setLevel(self.logLevel)

			VMRunHandler.serviceMode = mode

			if self.tcp && self.address.isEmpty == false {
				throw ValidationError(String(localized: "Both tcp and address are set, only one is allowed"))
			}

			if self.insecure == false {
				if let caCert, let tlsCert, let tlsKey {
					if FileManager.default.fileExists(atPath: caCert) == false {
						throw ValidationError(String(localized: "Root certificate file not found: \(caCert)"))
					}

					if FileManager.default.fileExists(atPath: tlsCert) == false {
						throw ValidationError(String(localized: "TLS certificate file not found: \(tlsCert)"))
					}

					if FileManager.default.fileExists(atPath: tlsKey) == false {
						throw ValidationError(String(localized: "TLS key file not found: \(tlsKey)"))
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
			if self.tcp {
				return [
					try Utils.getDefaultServerAddress(runMode: self.asSystem ? .system : .user),
					"tcp://0.0.0.0:\(Caked.defaultServicePort)",
				]
			}

			if self.address.isEmpty {
				return [try Utils.getDefaultServerAddress(runMode: self.asSystem ? .system : .user)]
			}

			return address
		}
	}

	struct Install: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: String(localized: "Install caked daemon as launchctl agent"))

		@OptionGroup(title: String(localized: "Agent common options"))
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

			try ServiceHandler.installAgent(listenAddress: listenAddress, insecure: self.options.insecure, rest: self.options.rest, password: (self.options.noPassword ? "" : self.options.password), caCert: caCert, tlsCert: tlsCert, tlsKey: tlsKey, runMode: runMode)
		}
	}

	struct Listen: AsyncParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: String(localized: "caked daemon listening"))

		@Flag(help: .hidden)
		var secure: Bool = false

		@OptionGroup(title: String(localized: "Agent common options"))
		var options: ServiceOptions

		var password: String? {
			if options.noPassword { return nil }
			if let password = options.password { return password }
			return try? CakedKeyConfig.passphrase.get()
		}

		var webUIDirectory: String? {
			if self.options.webUIDirectory != nil {
				return self.options.webUIDirectory
			}
			
			return Bundle.main.path(forResource: "webui", ofType: "zip")
		}

		mutating func validate() throws {
			let runMode: Utils.RunMode = self.options.runMode

			if self.secure {
				let certs = try CertificatesLocation.createCertificats(runMode: runMode)

				self.options.caCert = certs.caCertURL.path
				self.options.tlsCert = certs.serverCertURL.path
				self.options.tlsKey = certs.serverKeyURL.path
			} else if let caCert = self.options.caCert, let tlsCert = self.options.tlsCert, let tlsKey = self.options.tlsKey {
				if FileManager.default.fileExists(atPath: caCert) == false {
					throw ServiceError(String(localized: "Root certificate file not found: \(caCert)"))
				}

				if FileManager.default.fileExists(atPath: tlsCert) == false {
					throw ServiceError(String(localized: "TLS certificate file not found: \(tlsCert)"))
				}

				if FileManager.default.fileExists(atPath: tlsKey) == false {
					throw ServiceError(String(localized: "TLS key file not found: \(tlsKey)"))
				}
			} else if (self.options.tlsKey != nil || self.options.tlsCert != nil) && (self.options.tlsKey == nil || self.options.tlsCert == nil) {
				throw ServiceError(String(localized: "Some cert files not provided"))
			}
		}

		func run() async throws {
			let listenAddress = try self.options.getListenAddress()
			let logger = Logger(self)

			guard listenAddress.count > 0 else {
				logger.error("No listen address provided")
				throw ServiceError(String(localized: "No listen address provided"))
			}

			let runMode: Utils.RunMode = self.options.runMode
			let home = try Home(runMode: runMode)
			let eventLoopGroup = Utilities.group

			defer {
				try? home.agentPID.delete()
			}

			try CakedLib.StartHandler.autostart(on: eventLoopGroup.next(), runMode: runMode).whenComplete { result in
				switch result {
				case .failure(let error):
					logger.error("Failed to autostart: \(error.localizedDescription)")
				case .success:
					logger.info("Autostart completed")
				}
			}

			let provider = try CakedProvider(group: eventLoopGroup, password: self.password, runMode: runMode)
			let servers: [Server] = try listenAddress.map { address in
				logger.info("Start listening on \(address)")

				return try ServiceHandler.createServer(
					eventLoopGroup: eventLoopGroup,
					runMode: runMode,
					listeningAddress: URL(string: address),
					serviceProviders: [provider],
					password: self.password,
					caCert: self.options.caCert,
					tlsCert: self.options.tlsCert,
					tlsKey: self.options.tlsKey
				).wait()
			}

			// Start LXD REST API server if enabled
			var restServer: LXDRESTServer? = nil

			if self.options.rest {
				var port = self.options.restPort
				var components = URLComponents()

				if port == 0 {
					if self.options.tlsCert != nil && self.options.tlsKey != nil {
						port = 8443
					} else {
						port = 8080
					}
				}

				components.scheme = (self.options.tlsCert != nil && self.options.tlsKey != nil) ? "https" : "http"
				components.host = "0.0.0.0"
				components.port = port
				components.password = self.password

				if let listen = components.url {
					do {
						restServer = try await LXDRESTServer(group: eventLoopGroup, listen: listen, caCert: self.options.caCert, tlsCert: self.options.tlsCert, tlsKey: self.options.tlsKey, runMode: runMode, webUIDirectory: self.webUIDirectory)
						try restServer?.start()
						logger.info("LXD REST API listening on \(listen.hiddenPasswordURL)")
					} catch {
						logger.error("Failed to start LXD REST server: \(error.localizedDescription)")
					}
				}
			}

			Root.sigintSrc.cancel()

			signal(SIGINT, SIG_IGN)

			typealias AsyncStreamVoid = (
				stream: AsyncStream<Void>,
				continuation: AsyncStream<Void>.Continuation
			)

			let sigintSrc: any DispatchSourceSignal = DispatchSource.makeSignalSource(signal: SIGINT)
			var stream: AsyncStreamVoid? = nil

			sigintSrc.setEventHandler {
				logger.info("Stop service on SIGINT")

				stream = AsyncStream.makeStream(of: Void.self)

				Task {
					await restServer?.shutdown()
					provider.stop()

					try? await EventLoopFuture.andAllComplete(
						servers.map {
							$0.initiateGracefulShutdown()
						}, on: eventLoopGroup.next()
					).get()

					stream?.continuation.finish()

					logger.info("Server nicely closed")
				}
			}

			sigintSrc.activate()

			try home.agentPID.writePID()

			// Wait on the server's `onClose` future to stop the program from exiting.
			let futures = EventLoopFuture.andAllComplete(
				servers.map {
					$0.onClose
				}, on: eventLoopGroup.next())

			futures.whenComplete { _ in
				logger.info("All servers closed")
			}

			try await futures.get()

			if let stream = stream {
				for await _ in stream.stream {
					break
				}
			}

			logger.info("Leave service")
		}
	}

	struct Show: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: String(localized: "Help to run caked daemon"))

		@OptionGroup(title: String(localized: "Agent common options"))
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

			if self.options.noPassword {
				arguments.append("--no-pass-phrase")
			} else if let provided = self.options.password {
				arguments.append("--pass-phrase=\(provided)")
			}

			Logger.appendNewLine(arguments.joined(separator: " "))
		}
	}

	struct Status: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: String(localized: "Tell the status of caked daemon"))

		@Flag(help: ArgumentHelp(String(localized: "Output format: text or json")))
		var format: Format = .text

		struct ServiceStatus: Codable {
			let installed: Bool
			let run: Bool
			let pid: String
			let mode: Utils.RunMode
		}

		mutating func run() throws {
			let running = ServiceHandler.isAgentRunningWithPID
			let status = ServiceStatus(
				installed: ServiceHandler.isAgentInstalled,
				run: running.running,
				pid: running.pid == nil ? String.empty : String(running.pid!),
				mode: ServiceHandler.runningMode)

			print(self.format.renderSingle(status))
		}
	}

	struct Stop: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: String(localized: "Tell to stop caked daemon"))

		mutating func run() throws {
			let mode = ServiceHandler.runningMode

			guard mode != .app && ServiceHandler.isAgentRunning(runMode: mode).running else {
				throw ServiceError(String(localized: "Caked service is not running"))
			}

			if ServiceHandler.isAgentInstalled(runMode: mode) {
				try ServiceHandler.stopAgent(runMode: mode)
			} else {
				try ServiceHandler.stopAgentRunning(runMode: mode)
			}
		}
	}
}

