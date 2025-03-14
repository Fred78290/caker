import ArgumentParser
import Darwin
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import NIOSSL
import SwiftDate
import Logging

class GrpcError: Error {
	let code: Int
	let reason: String

	init(code: Int, reason: String) {
		self.code = code
		self.reason = reason
	}
}

protocol GrpcParsableCommand: ParsableCommand {
	var options: Client.Options { get }

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply
}

protocol AsyncGrpcParsableCommand: AsyncParsableCommand, GrpcParsableCommand {
	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) async throws -> Caked_Reply
}

extension AsyncGrpcParsableCommand {
	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		throw CleanExit.helpRequest(self)
	}

	public mutating func run() async throws {
		do {
			let response = try await self.options.execute(command: self, arguments: self.options.arguments)

			if response.count > 0 {
				print(response)
			}
		} catch {
			if let err = error as? GrpcError {
				fputs("\(err.reason)\n", stderr)

				Foundation.exit(Int32(err.code))
			}
			// Handle any other exception, including ArgumentParser's ones
			Self.exit(withError: error)
		}
	}
}

extension GrpcParsableCommand {
	public mutating func run() throws {
		do {
			let response = try self.options.execute(command: self, arguments: self.options.arguments)

			if response.count > 0 {
				print(response)
			}
		} catch {
			if let err = error as? GrpcError {
				fputs("\(err.reason)\n", stderr)

				Foundation.exit(Int32(err.code))
			}
			// Handle any other exception, including ArgumentParser's ones
			Self.exit(withError: error)
		}
	}
}

@main
struct Client: AsyncParsableCommand {
	struct Options: ParsableArguments {
		var commandName: String? = nil
		var arguments: [String] = []

		init() {
			let discardedOptions: [String] = [
				"--insecure",
				"--log-level",
				"--timeout",
				"--system",
				"--connect",
				"--ca-cert",
				"--tls-cert",
				"--tls-key",
			]

			for argument in CommandLine.arguments.dropFirst() {
				if discardedOptions.contains(argument) == false {
					if argument.hasPrefix("-") || commandName != nil {
						arguments.append(argument)
					} else if commandName == nil {
						commandName = argument
					}
				}
			}
		}

		@Option(help: "Connection timeout in seconds")
		public var timeout: Int64 = 120

		@Flag(name: [.customLong("insecure")], help: "don't use TLS")
		public var insecure: Bool = false

		@Flag(name: [.customLong("system")], help: "Caked run as system agent")
		public var asSystem: Bool = false

		@Option(name: [.customLong("connect")], help: "connect to address")
		public var address: String = try! Client.getDefaultServerAddress(asSystem: false)

		@Option(name: [.customLong("ca-cert")], help: "CA TLS certificate")
		public var caCert: String? = nil

		@Option(name: [.customLong("tls-cert")], help: "Client TLS certificate")
		public var tlsCert: String? = nil

		@Option(name: [.customLong("tls-key")], help: "Client private key")
		public var tlsKey: String? = nil

		func prepareClient() throws -> (EventLoopGroup, CakeAgentClient) {
			let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
			let connection = try Client.createClient(on: group,
			                                         listeningAddress: URL(string: self.address),
			                                         connectionTimeout: self.timeout,
			                                         caCert: self.caCert,
			                                         tlsCert: self.tlsCert,
			                                         tlsKey: self.tlsKey)

			return (group, CakeAgentClient(channel: connection, interceptors: CakeAgentClientInterceptorFactory()))
		}

		func execute(command: GrpcParsableCommand, arguments: [String]) throws -> String {
			let (group, grpcClient) = try prepareClient()

			defer {
				try? grpcClient.channel.close().wait()
				try? group.syncShutdownGracefully()
			}

			let reply = try command.run(client: grpcClient, arguments: arguments, callOptions: CallOptions(timeLimit: .none))

			switch reply.response {
			case let .error(err):
				throw GrpcError(code: Int(err.code), reason: err.reason)
			case let .output(msg):
				return msg
			case .none:
				throw GrpcError(code: -1, reason: "No reply")
			}
		}

		func execute(command: AsyncGrpcParsableCommand, arguments: [String]) async throws -> String {
			let (group, grpcClient) = try prepareClient()
			let finish = {
				try? await grpcClient.channel.close().get()
				try? await group.shutdownGracefully()
			}

			do {
				let reply = try await command.run(client: grpcClient, arguments: arguments, callOptions: CallOptions(timeLimit: .none))

				await finish()

				switch reply.response {
				case let .error(err):
					throw GrpcError(code: Int(err.code), reason: err.reason)
				case let .output(msg):
					return msg
				case .none:
					throw GrpcError(code: -1, reason: "No reply")
				}
			} catch {
				await finish()
				throw error
			}
		}

		mutating func validate() throws {
			if self.insecure {
				self.caCert = nil
				self.tlsCert = nil
				self.tlsKey = nil
			} else {
				if self.tlsCert == nil && self.tlsKey == nil {
					let certs = try ClientCertificatesLocation.getCertificats(asSystem: self.asSystem)

					if certs.exists() {
						self.caCert = certs.caCertURL.path()
						self.tlsCert = certs.clientCertURL.path()
						self.tlsKey = certs.clientKeyURL.path()
					}
				}
			}
		}
	}

	@OptionGroup var options: Client.Options

	static var configuration = CommandConfiguration(
		commandName: "cakectl",
		version: CI.version,
		subcommands: [
			Build.self,
			Configure.self,
			Delete.self,
			Exec.self,
			ImagesManagement.self,
			Infos.self,
			Launch.self,
			List.self,
			Networks.self,
			Purge.self,
			Remote.self,
			Rename.self,
			Sh.self,
			Start.self,
			Stop.self,
			Template.self,
			WaitIP.self,
			Mount.self,
			Umount.self,

			Clone.self,
			Login.self,
			Logout.self,
			Pull.self,
			Push.self,
			Import.self,
			Export.self,
		])

	static func getDefaultServerAddress(asSystem: Bool) throws -> String {
		if let cakeListenAddress = ProcessInfo.processInfo.environment["CAKE_LISTEN_ADDRESS"] {
			return cakeListenAddress
		} else {
			var tartHomeDir = try Utils.getHome(asSystem: asSystem)

			tartHomeDir.append(path: ".caked.sock")

			return "unix://\(tartHomeDir.absoluteURL.path())"
		}
	}

	static func createClient(on: EventLoopGroup,
	                         listeningAddress: URL?,
	                         connectionTimeout: Int64 = 60,
	                         caCert: String?,
	                         tlsCert: String?,
	                         tlsKey: String?) throws -> ClientConnection {
		if let listeningAddress = listeningAddress {
			let target: ConnectionTarget

			if listeningAddress.scheme == "unix" || listeningAddress.isFileURL {
				target = ConnectionTarget.unixDomainSocket(listeningAddress.path())
			} else if listeningAddress.scheme == "tcp" {
				target = ConnectionTarget.hostAndPort(listeningAddress.host ?? "127.0.0.1", listeningAddress.port ?? 5000)
			} else {
				throw GrpcError(
					code: -1,
					reason:
					"unsupported address scheme: \(String(describing: listeningAddress.scheme))")
			}

			var clientConfiguration = ClientConnection.Configuration.default(target: target, eventLoopGroup: on)

			if let tlsCert = tlsCert, let tlsKey = tlsKey {
				let tlsCert = try NIOSSLCertificate(file: tlsCert, format: .pem)
				let tlsKey = try NIOSSLPrivateKey(file: tlsKey, format: .pem)
				let trustRoots: NIOSSLTrustRoots

				if let caCert: String = caCert {
					trustRoots = .certificates([try NIOSSLCertificate(file: caCert, format: .pem)])
				} else {
					trustRoots = NIOSSLTrustRoots.default
				}

				clientConfiguration.tlsConfiguration = GRPCTLSConfiguration.makeClientConfigurationBackedByNIOSSL(
					certificateChain: [.certificate(tlsCert)],
					privateKey: .privateKey(tlsKey),
					trustRoots: trustRoots,
					certificateVerification: .noHostnameVerification)
			}

			clientConfiguration.connectionBackoff = ConnectionBackoff(maximumBackoff: TimeInterval(connectionTimeout), minimumConnectionTimeout: TimeInterval(connectionTimeout), retries: .upTo(1))

			return ClientConnection(configuration: clientConfiguration)
		}

		throw GrpcError(code: -1, reason: "connection address must be specified")
	}

	static func parse() throws -> GrpcParsableCommand? {
		do {
			return try parseAsRoot() as? GrpcParsableCommand
		} catch {
			return nil
		}
	}

	mutating func run() async throws {
		// Ensure the default SIGINT handled is disabled,
		// otherwise there's a race between two handlers
		signal(SIGINT, SIG_IGN)
		// Handle cancellation by Ctrl+C ourselves
		let task = withUnsafeCurrentTask { $0 }!
		let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT)
		sigintSrc.setEventHandler {
			task.cancel()
		}
		sigintSrc.activate()

		// Set line-buffered output for stdout
		setlinebuf(stdout)

		try self.options.validate()

		// Parse and run command
		do {
			guard let command = try Self.parse() else {
				if let commandName = self.options.commandName {
					let command: any GrpcParsableCommand = Cake(command: commandName)
					let response = try self.options.execute(command: command, arguments: self.options.arguments)

					if response.count > 0 {
						print(response)
					}
				} else {
					let usage = Self.usageString() + "\n"

					FileHandle.standardError.write(usage.data(using: .utf8)!)
				}

				Foundation.exit(-1)
			}

			let response: String

			if let command = command as? AsyncGrpcParsableCommand {
				response = try await self.options.execute(command: command, arguments: self.options.arguments)
			} else {
				response = try self.options.execute(command: command, arguments: self.options.arguments)
			}

			if response.count > 0 {
				print(response)
			}
		} catch {
			if let err = error as? GrpcError {
				fputs("\(err.reason)\n", stderr)

				Foundation.exit(Int32(err.code))
			}
			// Handle any other exception, including ArgumentParser's ones
			Self.exit(withError: error)
		}
	}
}
