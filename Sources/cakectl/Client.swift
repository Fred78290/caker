import ArgumentParser
import Darwin
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib
import NIOCore
import NIOPosix
import NIOSSL
import SwiftDate

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
	var retries: ConnectionBackoff.Retries { get }
	var callOptions: CallOptions? { get }
	var interceptors: Caked_ServiceClientInterceptorFactoryProtocol? { get }

	func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String
}

protocol AsyncGrpcParsableCommand: AsyncParsableCommand, GrpcParsableCommand {
	func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String
}

extension AsyncGrpcParsableCommand {
	func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		throw CleanExit.helpRequest(self)
	}

	public mutating func run() async throws {
		do {
			let response = try await self.options.execute(command: self, arguments: self.options.arguments)

			if response.count > 0 {
				print(response)
			}
		} catch {
			Client.handleError(error)
		}
	}
}

extension GrpcParsableCommand {
	var retries: ConnectionBackoff.Retries {
		.upTo(1)
	}

	var interceptors: Caked_ServiceClientInterceptorFactoryProtocol? {
		nil
	}

	var callOptions: CallOptions? {
		CallOptions(timeLimit: .none)
	}

	public mutating func run() throws {
		do {
			let response = try self.options.execute(command: self, arguments: self.options.arguments)

			if response.count > 0 {
				print(response)
			}
		} catch {
			Client.handleError(error)
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
				"--disable-tls",
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
		public var timeout: Int64 = 10

		@Flag(name: [.customLong("disable-tls")], help: "Don't use TLS")
		public var insecure: Bool = false

		@Flag(name: [.customLong("system")], help: "Caked run as system agent")
		public var asSystem: Bool = false

		@Option(name: [.customLong("connect")], help: ArgumentHelp("Connect to address", valueName: "address"))
		public var address: String = try! Utils.getDefaultServerAddress(runMode: .user)

		@Option(name: [.customLong("ca-cert")], help: ArgumentHelp("CA TLS certificate", valueName: "path"))
		public var caCert: String? = nil

		@Option(name: [.customLong("tls-cert")], help: ArgumentHelp("Client TLS certificate", valueName: "path"))
		public var tlsCert: String? = nil

		@Option(name: [.customLong("tls-key")], help: ArgumentHelp("Client private key", valueName: "path"))
		public var tlsKey: String? = nil

		func prepareClient(retries: ConnectionBackoff.Retries, interceptors: Caked_ServiceClientInterceptorFactoryProtocol?) throws -> (EventLoopGroup, CakeServiceClient) {
			let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
			let connection = try Client.createClient(
				on: group,
				listeningAddress: URL(string: self.address),
				connectionTimeout: self.timeout,
				retries: retries,
				caCert: self.caCert,
				tlsCert: self.tlsCert,
				tlsKey: self.tlsKey)

			return (group, CakeServiceClient(channel: connection, interceptors: interceptors))
		}

		func execute(command: GrpcParsableCommand, arguments: [String]) throws -> String {
			let (group, grpcClient) = try prepareClient(retries: command.retries, interceptors: command.interceptors)

			defer {
				try? grpcClient.channel.close().wait()
				try? group.syncShutdownGracefully()
			}

			return try command.run(client: grpcClient, arguments: arguments, callOptions: command.callOptions)
		}

		func execute(command: AsyncGrpcParsableCommand, arguments: [String]) async throws -> String {
			let (group, grpcClient) = try prepareClient(retries: command.retries, interceptors: command.interceptors)
			let finish = {
				try? await grpcClient.channel.close().get()
				try? await group.shutdownGracefully()
			}

			do {
				let reply = try await command.run(client: grpcClient, arguments: arguments, callOptions: command.callOptions)

				await finish()

				return reply
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
					let certs = try ClientCertificatesLocation.getCertificats(runMode: self.asSystem ? .system : .user)

					if certs.exists() {
						self.caCert = certs.caCertURL.path
						self.tlsCert = certs.clientCertURL.path
						self.tlsKey = certs.clientKeyURL.path
					}
				}
			}
		}
	}

	@OptionGroup(title: "Client options")
	var options: Client.Options

	static let configuration = CommandConfiguration(
		commandName: "cakectl",
		version: CI.version,
		subcommands: [
			Build.self,
			Configure.self,
			Delete.self,
			Duplicate.self,
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
			Suspend.self,
			Template.self,
			WaitIP.self,
			Mount.self,
			Umount.self,

			Login.self,
			Logout.self,
			Pull.self,
			Push.self,
		])

	static func createClient(
		on: EventLoopGroup,
		listeningAddress: URL?,
		connectionTimeout: Int64 = 60,
		retries: ConnectionBackoff.Retries,
		caCert: String?,
		tlsCert: String?,
		tlsKey: String?
	) throws -> ClientConnection {
		if let listeningAddress = listeningAddress {
			let target: ConnectionTarget

			if listeningAddress.scheme == "unix" || listeningAddress.isFileURL {
				target = ConnectionTarget.unixDomainSocket(listeningAddress.path)
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
				clientConfiguration.tlsConfiguration = try GRPCTLSConfiguration.makeClientConfiguration(
					caCert: caCert,
					tlsKey: tlsKey,
					tlsCert: tlsCert)
			}

			clientConfiguration.connectionBackoff = ConnectionBackoff(maximumBackoff: TimeInterval(connectionTimeout), minimumConnectionTimeout: TimeInterval(connectionTimeout), retries: retries)

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

	static func handleError(_ error: Error) {
		var error = error

		if let status = error as? GRPCStatusTransformable {
			error = status.makeGRPCStatus()
		}

		if let err = error as? GRPCStatus {
			let description = err.code == .unavailable || err.code == .cancelled ? "Connection refused" : err.description

			FileHandle.standardError.write("\(description)\n".data(using: .utf8)!)
			Foundation.exit(Int32(err.code.rawValue))
		}

		if let err = error as? GrpcError {
			FileHandle.standardError.write("\(err.reason)\n".data(using: .utf8)!)
			Foundation.exit(Int32(err.code))
		}

		// Handle any other exception, including ArgumentParser's ones
		Self.exit(withError: error)
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
			Self.handleError(error)
		}
	}
}
