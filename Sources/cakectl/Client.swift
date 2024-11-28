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
	func run(client: Caked_ServiceNIOClient, arguments: [String]) throws -> Caked_Reply
}

@main
struct Client: ParsableCommand {
	static var configuration = CommandConfiguration(
		commandName: "cakectl",
		version: CI.version,
		subcommands: [
			Build.self,
			Start.self,
			Create.self,
			Clone.self,
			Set.self,
			Get.self,
			Launch.self,
			List.self,
			Login.self,
			Logout.self,
			IP.self,
			Pull.self,
			Push.self,
			Import.self,
			Export.self,
			Prune.self,
			Rename.self,
			Stop.self,
			Delete.self,
			FQN.self,
		])

	@Flag(name: [.customLong("insecure"), .customShort("k")], help: "don't use TLS")
	var insecure: Bool = false

	@Flag(name: [.customLong("system"), .customShort("s")], help: "Caked run as system agent")
	var asSystem: Bool = false

	@Option(name: [.customLong("address"), .customShort("l")], help: "connect to address")
	var address: String = try! Self.getDefaultServerAddress(asSystem: false)

	@Option(name: [.customLong("ca-cert"), .customShort("c")], help: "CA TLS certificate")
	var caCert: String?

	@Option(name: [.customLong("tls-cert"), .customShort("t")], help: "Client TLS certificate")
	var tlsCert: String?

	@Option(name: [.customLong("tls-key"), .customShort("k")], help: "Client private key")
	var tlsKey: String?

	static func getDefaultServerAddress(asSystem: Bool) throws -> String {
		if let cakeListenAddress = ProcessInfo.processInfo.environment["CAKED_LISTEN_ADDRESS"] {
			return cakeListenAddress
		} else {
			var tartHomeDir = try Utils.getHome(asSystem: asSystem)

			tartHomeDir.append(path: "caked.sock")

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

			if listeningAddress.scheme == "unix" {
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

	func execute(command: GrpcParsableCommand, arguments: [String]) throws -> String {
		let command = command
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		// Make sure the group is shutdown when we're done with it.
		defer {
			try! group.syncShutdownGracefully()
		}

		let connection = try Self.createClient(on: group,
		                                       listeningAddress: URL(string: self.address),
		                                       caCert: self.caCert,
		                                       tlsCert: self.tlsCert,
		                                       tlsKey: self.tlsKey)

		defer {
			try! connection.close().wait()
		}

		let grpcClient = Caked_ServiceNIOClient(channel: connection)
		let reply = try command.run(client: grpcClient, arguments: arguments)

		return reply.output
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

		if self.insecure {
			self.caCert = nil
			self.tlsCert = nil
			self.tlsKey = nil
		} else {
			if self.tlsCert == nil && self.tlsKey == nil {
				let certs = try CertificatesLocation.getCertificats(asSystem: self.asSystem)

				if certs.exists() {
					self.caCert = certs.caCertURL.path()
					self.tlsCert = certs.clientCertURL.path()
					self.tlsKey = certs.clientKeyURL.path()
				}
			}
		}

		// Parse and run command
		do {
			var commandName: String?
			var arguments: [String] = []
			for argument in CommandLine.arguments.dropFirst() {
				if argument.hasPrefix("-") || commandName != nil {
					arguments.append(argument)
				} else if commandName == nil {
					commandName = argument
				}
			}

			guard let command = try Self.parse() else {
				let command: any GrpcParsableCommand = Cake(command: commandName)

				print(try self.execute(command: command, arguments: arguments))

				return
			}

			print(try self.execute(command: command, arguments: arguments))
		} catch {
			// Handle any other exception, including ArgumentParser's ones
			Self.exit(withError: error)
		}
	}
}
