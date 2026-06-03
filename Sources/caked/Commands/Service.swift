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
import Combine
import X509

struct Certs {
	let ca: String?
	let key: String?
	let cert: String?
}

#if USE_SMSERVICE
fileprivate let subcommands: [ParsableCommand.Type] = [
	Service.Listen.self,
	Service.Show.self,
	Service.Status.self,
	Service.Stop.self,
]
#else
fileprivate let subcommands: [ParsableCommand.Type] = [
	Service.Install.self,
	Service.Listen.self,
	Service.Show.self,
	Service.Status.self,
	Service.Stop.self,
]
#endif

struct Service: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: String(localized: "caked as launchctl agent"), subcommands: subcommands)
}

extension Service {
	struct ServiceOptions: ParsableArguments {
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

		@Option(name: [.customLong("rest-log-level")], help: ArgumentHelp(String(localized: "Log level"), visibility: .hidden))
		public var restLogLevel: CakeAgentLib.Logger.LogLevel = .warning

		@Option(name: [.customLong("rest-port")], help: ArgumentHelp(String(localized: "Override LXD REST API listen port"), discussion: "By default LXD will listen on 8443 for https and 8080 for http"))
		var restPort: Int = 0

		@Option(name: [.customLong("web-ui")], help: ArgumentHelp(String(localized: "Path to web UI static files directory"), discussion: "When provided, caked serves the web UI under /ui"))
		var webUIDirectory: String? = nil

		func validate() throws {
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

		func getCertificats(runMode: Utils.RunMode) throws -> Certs {
			if self.tlsCert == nil && self.tlsKey == nil {
				let certs = try CertificatesLocation.createCertificats(runMode: runMode)

				return Certs(ca: certs.caCertURL.path, key: certs.serverKeyURL.path, cert: certs.serverCertURL.path)
			}

			return Certs(ca: self.caCert, key: self.tlsKey, cert: self.tlsCert)
		}

		func getListenAddress(runMode: Utils.RunMode) throws -> [String] {
			if self.tcp {
				return [
					try Utils.getDefaultServerAddress(runMode: runMode),
					"tcp://0.0.0.0:\(Caked.defaultServicePort)",
				]
			}

			if self.address.isEmpty {
				return [try Utils.getDefaultServerAddress(runMode: runMode)]
			}

			return address
		}
	}

	struct Install: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: String(localized: "Install caked daemon as launchctl agent"))

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@OptionGroup(title: String(localized: "Agent common options"))
		var options: ServiceOptions

		var password: String? {
			if options.noPassword { return nil }

			if let password = options.password { return password }

			return try? CakedKeyConfig.passphrase.get()
		}

		func run() throws {
			let runMode: Utils.RunMode = self.common.runMode

			if self.options.address.isEmpty && self.options.caCert == nil && self.options.tlsCert == nil && self.options.tlsKey == nil {
				try ServiceHandler.installAgent(insecure: self.options.insecure, tcp: self.options.tcp, rest: self.options.rest, password: self.password, runMode: runMode)
			} else {
				let caCert = self.options.caCert
				let tlsCert = self.options.tlsCert
				let tlsKey = self.options.tlsKey

				if self.options.insecure == false && caCert == nil && tlsCert == nil && tlsKey == nil {
					_ = try self.options.getCertificats(runMode: runMode)
				}

				try ServiceHandler.installAgent(
					listenAddress: try self.options.getListenAddress(runMode: runMode),
					insecure: self.options.insecure,
					rest: self.options.rest,
					password: self.password,
					caCert: caCert,
					tlsCert: tlsCert,
					tlsKey: tlsKey,
					runMode: runMode)
			}
		}
	}

	struct Listen: AsyncParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: String(localized: "caked daemon listening"))

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@OptionGroup(title: String(localized: "Agent common options"))
		var options: ServiceOptions

		@Flag(help: .hidden)
		var secure: Bool = false

		@Flag(help: .hidden)
		var log: Bool = false

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

		private var loggingCancellable: Cancellable?

		init() {
		}

		init(from: Decoder) throws {
			throw ServiceError("Direct initialization of Listen command is not supported")
		}

		mutating func validate() throws {
			let runMode: Utils.RunMode = self.common.runMode

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

		private func setupLogging() -> Cancellable? {
			guard self.log else {
				return nil
			}

			let logURL = URL(fileURLWithPath: Utils.getOutputLog(runMode: self.common.runMode))

			do {
				return try TeeStandardIOWrapper(logURL: logURL)
			} catch {
				// Best effort: if tee setup fails, keep running without tee
			}

			return nil
		}

		func xpc() -> xpc_connection_t {
			let listener = xpc_connection_create_mach_service("com.aldunelabs.caked.xpc", nil, UInt64(XPC_CONNECTION_MACH_SERVICE_LISTENER))

			xpc_connection_set_event_handler(listener) { peer in
				if xpc_get_type(peer) != XPC_TYPE_CONNECTION {
					return
				}

				xpc_connection_set_event_handler(peer) { request in
					if xpc_get_type(request) == XPC_TYPE_DICTIONARY {
						let message = xpc_dictionary_get_string(request, "MessageKey")
						let encodedMessage = String(cString: message!)
						let reply = xpc_dictionary_create_reply(request)
						let response = "Hello \(encodedMessage)"
						response.withCString { rawResponse in
							xpc_dictionary_set_string(reply!, "ResponseKey", rawResponse)
						}
						xpc_connection_send_message(peer, reply!)
					}
				}

				xpc_connection_activate(peer)
			}

			xpc_connection_activate(listener)

			return listener
		}

		func run() async throws {
			let listenAddress = try self.options.getListenAddress(runMode: self.common.runMode)
			let logger = Logger(self)

			guard listenAddress.count > 0 else {
				logger.error("No listen address provided")
				throw ServiceError(String(localized: "No listen address provided"))
			}

			let runMode: Utils.RunMode = self.common.runMode
			let home = try Home(runMode: runMode)
			let eventLoopGroup = Utilities.group
			//let listener = self.xpc()

			defer {
				//xpc_connection_cancel(listener)

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
			let servers = listenAddress.compactMap { address in
				logger.info("Start listening on \(address)")

				do {
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
				} catch {
					logger.error("Failed to start server on \(address): \(error)")
				}

				return nil
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
						restServer = try await LXDRESTServer(
							group: eventLoopGroup, listen: listen, caCert: self.options.caCert, tlsCert: self.options.tlsCert, tlsKey: self.options.tlsKey, runMode: runMode, webUIDirectory: self.webUIDirectory, restLogLevel: self.options.restLogLevel
						)
						try restServer?.start()
						logger.info("LXD REST API listening on \(listen.hiddenPasswordURL)")
					} catch {
						logger.error("Failed to start LXD REST server: \(error)")
					}
				}
			}

			Root.sigintSrc.cancel()

			signal(SIGINT, SIG_IGN)

			try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
				let sigintSrc: any DispatchSourceSignal = DispatchSource.makeSignalSource(signal: SIGINT)

				sigintSrc.setEventHandler {
					logger.info("Stop service on SIGINT")

					Task {
						await restServer?.shutdown()
						provider.stop()

						try? await EventLoopFuture.andAllComplete(
							servers.map {
								$0.initiateGracefulShutdown()
							}, on: eventLoopGroup.next()
						).get()

						continuation.resume()
						logger.info("Server nicely closed")
					}
				}

				sigintSrc.activate()

				do {
					try home.agentPID.writePID()
				} catch {
					continuation.resume(throwing: error)
					return
				}

				// Wait on the server's `onClose` future to stop the program from exiting.
				let futures = EventLoopFuture.andAllComplete(
					servers.map {
						$0.onClose
					}, on: eventLoopGroup.next())

				futures.whenComplete { _ in
					logger.info("All servers closed")
				}

				try? futures.wait()
			}

			logger.info("Leave service")
		}
	}

	struct Show: ParsableCommand {
		static let configuration = CommandConfiguration(abstract: String(localized: "Help to run caked daemon"))

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@OptionGroup(title: String(localized: "Agent common options"))
		var options: ServiceOptions

		mutating func run() throws {
			let runMode = self.common.runMode
			let listenAddress = try self.options.getListenAddress(runMode: runMode)

			var arguments: [String] = [
				try ServiceHandler.findMe(),
				"service",
				"listen",
				"--secure",
				"--log-level=\(self.common.logLevel.rawValue)",
			]

			if self.options.tcp {
				arguments.append("--tcp")
			} else {
				arguments.append(contentsOf: listenAddress.map { "--address=\($0)" })
			}

			if self.options.rest {
				arguments.append("--rest")
				
				if self.options.restPort != 0 {
					arguments.append("--rest-port=\(self.options.restPort)")
				}

				if self.options.webUIDirectory != nil {
					arguments.append("--web-ui=\(self.options.webUIDirectory!)")
				}
			}

			if runMode == .system {
				arguments.append("--system")
			}

			if self.options.insecure == false {
				if self.options.caCert == nil && self.options.tlsCert == nil, self.options.tlsKey == nil {
					arguments.append("--secure")
				} else {
					let certs = try self.options.getCertificats(runMode: runMode)
					
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
