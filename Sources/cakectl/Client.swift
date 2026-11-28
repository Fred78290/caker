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
	func logHandler(_ label: String) -> LogHandler
}

extension GrpcCommand {
	func logHandler(_ label: String) -> LogHandler {
		StreamLogHandler.standardError(label: label)
	}

	var retries: ConnectionBackoff.Retries {
		.upTo(1)
	}
	
	var interceptors: Caked_ServiceClientInterceptorFactoryProtocol? {
		nil
	}
	
	var callOptions: CallOptions? {
		CallOptions(timeLimit: .none)
	}
	
	var password: String? {
		guard let password = options.password else {
			return CakedKeyConfig.passphrase.string()
		}

		return password
	}

	func prepareClient(group: EventLoopGroup) throws -> CakedServiceClient {
		let address = self.options.address

		guard var components = URLComponents(string: address) else {
			throw ServiceError("unsupported url: \(address)")
		}
		
		components.password = self.password

		let connection = try Caked.createClient(
			on: group,
			listeningAddress: components.url!,
			connectionTimeout: self.options.timeout,
			retries: retries,
			caCert: self.options.caCert,
			tlsCert: self.options.tlsCert,
			tlsKey: self.options.tlsKey,
			interceptors: self.interceptors)

		return connection
	}
}

/// Thrown by a command whose output must still be printed, but that must exit with `code` (130 after a cancel).
struct ExitWithOutput: Error {
	let output: String
	let code: Int32
}

protocol GrpcParsableCommand: ParsableCommand, GrpcCommand {
	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String
}

extension GrpcParsableCommand {
	public mutating func run() throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
		let grpcClient = try self.prepareClient(group: group)

		defer {
			try? grpcClient.channel.close().wait()
			try? group.syncShutdownGracefully()
		}

		do {
			try print(self.run(client: grpcClient, arguments: self.options.arguments, callOptions: self.callOptions))
		} catch let exit as ExitWithOutput {
			print(exit.output)
			throw ArgumentParser.ExitCode(exit.code)
		}
	}
}

protocol AsyncGrpcParsableCommand: AsyncParsableCommand, GrpcCommand {
	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String
}

extension AsyncGrpcParsableCommand {
	public mutating func run() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
		let grpcClient = try self.prepareClient(group: group)

		func finish() async {
			try? await grpcClient.channel.close().get()
			try? await group.shutdownGracefully()
		}

		do {
			try await print(self.run(client: grpcClient, arguments: self.options.arguments, callOptions: self.callOptions))
			await finish()
		} catch let exit as ExitWithOutput {
			print(exit.output)
			await finish()
			throw ArgumentParser.ExitCode(exit.code)
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

		@Option(name: [.customLong("pass-phrase")], help: ArgumentHelp(String(localized: "access password"), discussion: String(localized: "This option allows to protect the service endpoint with a password")))
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

		var runMode: Utils.RunMode {
			self.asSystem ? .system : .user
		}
		
		mutating func validate() throws {
			Logger.setLevel(self.logLevel)

			Utils.RunMode.current = self.runMode

			if self.insecure {
				self.caCert = nil
				self.tlsCert = nil
				self.tlsKey = nil
			} else {
				if self.tlsCert == nil && self.tlsKey == nil {
					let certs = try ClientCertificatesLocation.getCertificats(runMode: self.asSystem ? .system : .user)

					if certs.exists() {
						self.caCert = certs.caCertURL.path(percentEncoded: false)
						self.tlsCert = certs.clientCertURL.path(percentEncoded: false)
						self.tlsKey = certs.clientKeyURL.path(percentEncoded: false)
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
				Agent.self,
				Aliases.self,
				Apps.self,
				Build.self,
				Configure.self,
				Delete.self,
				Down.self,
				Duplicate.self,
				EnvInit.self,
				Exec.self,
				ImagesManagement.self,
				Infos.self,
				Launch.self,
				List.self,
				Networks.self,
				Provision.self,
				Purge.self,
				Remote.self,
				Rename.self,
				Sh.self,
				Start.self,
				Stop.self,
				Suspend.self,
				Template.self,
				Up.self,
				WaitIP.self,
				Mount.self,
				Umount.self,
				Login.self,
				Logout.self,
				Pull.self,
				Push.self,
				VNC.self,
				Seamless.self,
				SetOptions.self,
				GetOptions.self,
				Certificate.self,
				Sandbox.self,
				Compose.self,
				Tasks.self,
			])

#if DEBUG
		conf.subcommands.append(GrandCentralDispatch.self)
#endif

#if SPARKLE
		conf.subcommands.append(CheckUpdate.self)
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

	static let sigintSrc = {
		// Ensure the default SIGINT handled is disabled,
		// otherwise there's a race between two handlers
		signal(SIGINT, SIG_IGN)

		return DispatchSource.makeSignalSource(signal: SIGINT)
	}()

	public static func main() async throws {
		// Handle cancellation by Ctrl+C ourselves
		let task = withUnsafeCurrentTask { $0 }!

		sigintSrc.setEventHandler {
			task.cancel()

			sigintSrc.setEventHandler {
				Foundation.exit(128)
			}

			sigintSrc.activate()
		}

		sigintSrc.activate()

		// Set line-buffered output for stdout
		setlinebuf(stdout)

		// Parse and run command
		do {
			var command = try Self.parseAsRoot()

			if let grpcCommand = command as? GrpcCommand {
				// The factory is called once, synchronously, by bootstrap
				nonisolated(unsafe) let grpcCommand = grpcCommand

				LoggingSystem.bootstrap { label in
					grpcCommand.logHandler(label)
				}
			} else {
				// Set up logging to stderr
				LoggingSystem.bootstrap { label in
					StreamLogHandler.standardError(label: label)
				}
			}
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

extension Client {
	/// Replaces the default Ctrl-C handler: the first Ctrl-C asks caked to cancel task `taskID`, retried
	/// while caked hasn't registered it yet and until `finished` is set (by the caller, once the call that
	/// started the task has returned); the call then gets caked's "Cancelled" reply. A second Ctrl-C exits.
	@discardableResult
	static func cancelTaskOnInterrupt(client: CakedServiceClient, callOptions: CallOptions?, taskID: UUID, finished: CancellableTaskCompletion) -> DispatchSourceSignal {
		Client.sigintSrc.cancel()
		signal(SIGINT, SIG_IGN)

		// Not the main queue: a synchronous command (provision) blocks it while waiting for its async work
		let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global(qos: .userInitiated))

		sigintSrc.setEventHandler {
			Logger("Client").debug("SIGINT received, cancelling task \(taskID)")

			finished.requestCancel()

			// Said at once: the reply only comes once caked has cleaned up, which can take a while
			Self.notice(String(localized: "Cancelling… Press Ctrl-C again to quit without waiting."))

			Task {
				if await client.cancelTaskWhenRegistered(taskID, callOptions: callOptions, until: finished) {
					Self.notice(String(localized: "caked is cancelling the task and cleaning up…"))
				}
			}

			sigintSrc.setEventHandler {
				Self.notice(String(localized: "Quit without waiting: the task may still be running in caked."))
				Foundation.exit(128)
			}
		}

		sigintSrc.activate()

		return sigintSrc
	}

	/// A line on stderr, on its own line even when a progress bar was being drawn, and out of the
	/// command's own output (which a script may parse).
	private static func notice(_ message: String) {
		FileHandle.standardError.write(Data("\n\(message)\n".utf8))
	}

	/// The exit status of a command stopped by Ctrl-C.
	static let cancelledExitCode: Int32 = 130

	/// `output`, or, when the user cancelled the task with Ctrl-C and it didn't succeed, an `ExitWithOutput`
	/// that prints it and exits with `cancelledExitCode`. A task that finished before the cancel took is a success.
	static func output(_ output: String, for completion: CancellableTaskCompletion, succeeded: Bool) throws -> String {
		if completion.isCancelRequested && succeeded == false {
			throw ExitWithOutput(output: output, code: Self.cancelledExitCode)
		}

		return output
	}

	/// Runs `operation`, the call of the cancellable caked task `taskID`, with Ctrl-C cancelling that task
	/// (see `cancelTaskOnInterrupt`), and returns its reply rendered by `render`; see `output(_:for:succeeded:)`
	/// for the exit status of a cancelled one.
	static func cancellingTaskOnInterrupt<T>(
		client: CakedServiceClient, callOptions: CallOptions?, taskID: UUID, succeeded: (T) -> Bool, render: (T) -> String, _ operation: () async throws -> T
	) async throws -> String {
		let finished = CancellableTaskCompletion()
		let sigintSrc = Self.cancelTaskOnInterrupt(client: client, callOptions: callOptions, taskID: taskID, finished: finished)
		let reply: T

		do {
			defer {
				finished.finish()
				sigintSrc.cancel()
			}

			reply = try await operation()
		}

		return try Self.output(render(reply), for: finished, succeeded: succeeded(reply))
	}
}
