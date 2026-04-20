import ArgumentParser
import Darwin
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib
import CakedLib
import NIOCore
import NIOPosix
import NIOSSL
import SwiftDate
import Logging

protocol GrpcCommand {
	var options: Client.Options { get }
	var retries: ConnectionBackoff.Retries { get }
	var callOptions: CallOptions? { get }
	var interceptors: Caked_ServiceClientInterceptorFactoryProtocol? { get }
}

extension GrpcCommand {
	var retries: ConnectionBackoff.Retries {
		.upTo(1)
	}
	
	var interceptors: Caked_ServiceClientInterceptorFactoryProtocol? {
		nil
	}
	
	var callOptions: CallOptions? {
		CallOptions(timeLimit: .none)
	}
	
	func prepareClient() throws -> (EventLoopGroup, CakedServiceClient) {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
		let connection = try Caked.createClient(
			on: group,
			listeningAddress: URL(string: self.options.address),
			connectionTimeout: self.options.timeout,
			retries: retries,
			caCert: self.options.caCert,
			tlsCert: self.options.tlsCert,
			tlsKey: self.options.tlsKey,
			password: self.options.password,
			interceptors: self.interceptors)

		return (group, connection)
	}
}

protocol GrpcParsableCommand: ParsableCommand, GrpcCommand {
	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String
}

extension GrpcParsableCommand {
	public mutating func run() throws {
		let (group, grpcClient) = try self.prepareClient()

		defer {
			try? grpcClient.channel.close().wait()
			try? group.syncShutdownGracefully()
		}

		try print(self.run(client: grpcClient, arguments: self.options.arguments, callOptions: self.callOptions))
	}
}

protocol AsyncGrpcParsableCommand: AsyncParsableCommand, GrpcCommand {
	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String
}

extension AsyncGrpcParsableCommand {
	public mutating func run() async throws {
		let (group, grpcClient) = try self.prepareClient()

		func finish() async {
			try? await grpcClient.channel.close().get()
			try? await group.shutdownGracefully()
		}

		do {
			try await print(self.run(client: grpcClient, arguments: self.options.arguments, callOptions: self.callOptions))
			await finish()
		} catch {
			await finish()
			throw error
		}
	}
}

@main
struct Client: ParsableCommand {
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

		@Option(help: ArgumentHelp(String(localized: "Connection timeout in seconds")))
		public var timeout: Int64 = 10

		@Flag(name: [.customLong("disable-tls")], help: ArgumentHelp(String(localized: "Don't use TLS")))
		public var insecure: Bool = false

		@Flag(name: [.customLong("system")], help: ArgumentHelp(String(localized: "Caked run as system agent")))
		public var asSystem: Bool = false

		@Option(name: [.customLong("connect")], help: ArgumentHelp(String(localized: "Connect to address"), valueName: "address"))
		public var address: String = try! Utils.getDefaultServerAddress(runMode: .user)

		@Option(help: ArgumentHelp(String(localized: "access password"), discussion: String(localized: "This option allows to protect the service endpoint with a password")))
		public var password: String? = nil

		@Option(name: [.customLong("ca-cert")], help: ArgumentHelp(String(localized: "CA TLS certificate"), valueName: "path"))
		public var caCert: String? = nil

		@Option(name: [.customLong("tls-cert")], help: ArgumentHelp(String(localized: "Client TLS certificate"), valueName: "path"))
		public var tlsCert: String? = nil

		@Option(name: [.customLong("tls-key")], help: ArgumentHelp(String(localized: "Client private key"), valueName: "path"))
		public var tlsKey: String? = nil

		@Option(name: [.customLong("log-level")], help: ArgumentHelp(String(localized: "Log level")))
		public var logLevel: CakeAgentLib.Logger.LogLevel = .info

		@Flag(help: ArgumentHelp(String(localized: "Output format")))
		public var format: Format = .text

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)

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

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	nonisolated(unsafe)
	static var configuration: CommandConfiguration {
		var conf = CommandConfiguration(
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
				VNC.self,
			])

#if DEBUG
		conf.subcommands.append(GrandCentralDispatch.self)
#endif

		return conf
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

	public static func main() async throws {
		// Set up logging to stderr
		LoggingSystem.bootstrap { label in
			StreamLogHandler.standardError(label: label)
		}

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

		// Parse and run command
		do {
			var command = try Self.parseAsRoot()

			if var command = command as? AsyncParsableCommand {
				try await command.run()
			} else {
				try command.run()
			}
		} catch {
			Self.handleError(error)
		}
	}
}
