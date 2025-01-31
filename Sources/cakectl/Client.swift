import ArgumentParser
import Darwin
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import NIOSSL
import Sentry
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

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply
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
		var timeout: Int64 = 120

		@Flag(name: [.customLong("insecure")], help: "don't use TLS")
		var insecure: Bool = false

		@Flag(name: [.customLong("system")], help: "Caked run as system agent")
		var asSystem: Bool = false

		@Option(name: [.customLong("connect")], help: "connect to address")
		var address: String = try! Client.getDefaultServerAddress(asSystem: false)

		@Option(name: [.customLong("ca-cert")], help: "CA TLS certificate")
		var caCert: String?

		@Option(name: [.customLong("tls-cert")], help: "Client TLS certificate")
		var tlsCert: String?

		@Option(name: [.customLong("tls-key")], help: "Client private key")
		var tlsKey: String?

		func execute(command: GrpcParsableCommand, arguments: [String]) throws -> String {
			let command = command
			let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

			// Make sure the group is shutdown when we're done with it.
			defer {
				try! group.syncShutdownGracefully()
			}

			let connection = try Client.createClient(on: group,
			                                         listeningAddress: URL(string: self.address),
			                                         caCert: self.caCert,
			                                         tlsCert: self.tlsCert,
			                                         tlsKey: self.tlsKey)

			defer {
				try! connection.close().wait()
			}

			let grpcClient = Caked_ServiceNIOClient(channel: connection)
			let reply: Caked_Reply = try command.run(client: grpcClient, arguments: arguments, callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(self.timeout))))

			switch reply.response {
			case let .error(err):
				throw GrpcError(code: Int(err.code), reason: err.reason)
			case let .output(msg):
				return msg
			case .none:
				throw GrpcError(code: -1, reason: "No reply")
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
			Launch.self,
			Start.self,
			Stop.self,
			List.self,
			Configure.self,
			ImagesManagement.self,
			Remote.self,
			Delete.self,
			Networks.self,
			WaitIP.self,
			Purge.self,

			Create.self,
			Clone.self,
			Get.self,
			Login.self,
			Logout.self,
			IP.self,
			Pull.self,
			Push.self,
			Import.self,
			Export.self,
			Rename.self,
			FQN.self,
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

	static func createClient(on: MultiThreadedEventLoopGroup,
	                         listeningAddress: URL?,
	                         caCert: String?,
	                         tlsCert: String?,
	                         tlsKey: String?) throws -> ClientConnection {
		if let listeningAddress = listeningAddress {
			let target: ConnectionTarget

			if listeningAddress.scheme == "unix" && listeningAddress.isFileURL {
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

	mutating func run() throws {
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

			let response = try self.options.execute(command: command, arguments: self.options.arguments)

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
