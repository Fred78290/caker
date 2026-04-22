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
		
		@Option(help: ArgumentHelp(String(localized: "access password"), discussion: String(localized: "This option allows to protect the service endpoint with a password")))
		var password: String? = nil

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
					"tcp://0.0.0.0:\(Caked.defaultServicePort)"
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
			
			try ServiceHandler.installAgent(listenAddress: listenAddress, insecure: self.options.insecure, caCert: caCert, tlsCert: tlsCert, tlsKey: tlsKey, runMode: runMode)
		}
	}
	
	struct Listen: AsyncParsableCommand {
		static let configuration: CommandConfiguration = CommandConfiguration(abstract: String(localized: "caked daemon listening"))
		
		@Flag(help: .hidden)
		var secure: Bool = false
		
		@OptionGroup(title: String(localized: "Agent common options"))
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

			try home.agentPID.writePID()
			
			defer {
				try? home.agentPID.delete()
			}
			
			try CakedLib.StartHandler.autostart(on: eventLoopGroup.next(), runMode: runMode)
			
			let provider = try CakedProvider(group: eventLoopGroup, password: self.options.password, runMode: runMode)
			let servers: [Server] = try listenAddress.map { address in
				logger.info("Start listening on \(address)")

				return try ServiceHandler.createServer(
					eventLoopGroup: eventLoopGroup,
					runMode: runMode,
					listeningAddress: URL(string: address),
					serviceProviders: [provider],
					password: self.options.password,
					caCert: self.options.caCert,
					tlsCert: self.options.tlsCert,
					tlsKey: self.options.tlsKey
				).wait()
			}
			
			Root.sigintSrc.cancel()
			
			signal(SIGINT, SIG_IGN)

			let sigintSrc: any DispatchSourceSignal = DispatchSource.makeSignalSource(signal: SIGINT)
			
			sigintSrc.setEventHandler {
				logger.info("Stop service on SIGINT")
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
			
			logger.info("Service stopped")
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
			let status = ServiceStatus(installed: ServiceHandler.isAgentInstalled,
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
