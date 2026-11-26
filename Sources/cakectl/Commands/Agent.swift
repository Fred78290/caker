import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib

// MARK: - Agent command group

/// `cakectl agent version|install|update <vm>`: the cakeagent of a VM served by the connected caked, managed from the
/// command line (Caker.app's "Install agent"/"Update agent" button does the same).
struct Agent: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "agent",
		abstract: String(localized: "Show, install or update the cakeagent of a virtual machine"),
		discussion: String(localized: "The VM must be running. 'version' asks the agent which version it runs, 'install' always installs the agent over SSH, 'update' installs it only when the guest runs another version than the connected caked installs."),
		subcommands: [Version.self, Install.self, Update.self]
	)

	/// Ctrl-C for the agent commands. Their unary calls block in `wait()`, which the default handler (cancelling the main
	/// task) can't interrupt, so the first Ctrl-C did nothing and the second one killed the process. This cancels the call
	/// in flight instead, and the command ends with "Cancelled" and exit status 130; a second Ctrl-C still exits at once.
	/// Only the client stops: the connected caked finishes an install it has started.
	final class Interrupt: @unchecked Sendable {
		private let lock = NSLock()
		private var cancelCall: (() -> Void)? = nil
		private var interrupted = false
		private var source: DispatchSourceSignal? = nil

		init() {
			Client.sigintSrc.cancel()
			signal(SIGINT, SIG_IGN)

			let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())

			source.setEventHandler { [weak self] in
				source.setEventHandler {
					Foundation.exit(130)
				}

				self?.interrupt()
			}

			source.activate()
			self.source = source
		}

		deinit {
			self.source?.cancel()
		}

		private func interrupt() {
			let cancel = self.lock.withLock {
				self.interrupted = true

				return self.cancelCall
			}

			cancel?()
		}

		private var isInterrupted: Bool {
			self.lock.withLock { self.interrupted }
		}

		private func cancelled() -> Error {
			FileHandle.standardError.write("\(String(localized: "Cancelled"))\n".data(using: .utf8)!)

			return ArgumentParser.ExitCode(130)
		}

		/// Waits for a unary call's response, cancelling the call if Ctrl-C is pressed meanwhile (or was before).
		func wait<Request, Response>(_ call: UnaryCall<Request, Response>) throws -> Response {
			let alreadyInterrupted = self.lock.withLock {
				self.cancelCall = { call.cancel(promise: nil) }

				return self.interrupted
			}

			defer {
				self.lock.withLock { self.cancelCall = nil }
			}

			if alreadyInterrupted {
				call.cancel(promise: nil)

				throw self.cancelled()
			}

			do {
				// A response that won the race against Ctrl-C is kept: it reports what really happened (an install
				// that finished), and a following call of the same command is refused above.
				return try call.response.wait()
			} catch {
				if self.isInterrupted {
					throw self.cancelled()
				}

				throw error
			}
		}
	}

	/// The agent version a running VM reports, through the connected caked's `Info` call.
	static func version(client: CakedServiceClient, name: String, interrupt: Interrupt, callOptions: CallOptions?) throws -> AgentVersionReply {
		let reply = try interrupt.wait(client.info(.with { $0.name = name }, callOptions: callOptions)).vms.status

		guard reply.success else {
			throw ServiceError(reply.reason)
		}

		// Compare against what the connected caked installs; a caked that predates the field leaves it empty: unknown, never assumed.
		let expected: String? = reply.infos.installerAgentVersion.isEmpty ? nil : reply.infos.installerAgentVersion

		let status = VMInformations(reply.infos).status
		let running = status == .running || status == .provisioning

		return AgentVersionReply(name: name, running: running, version: reply.infos.agentVersion, expected: expected)
	}

	/// Asks the connected caked to install the agent, and fails the command when it could not.
	static func install(client: CakedServiceClient, name: String, sshTimeout: UInt, interrupt: Interrupt, callOptions: CallOptions?) throws -> AgentInstallReply {
		let reply = AgentInstallReply(InstalledAgentReply(try interrupt.wait(client.installAgent(.with {
			$0.name = name
			$0.timeout = Int32(clamping: sshTimeout)
		}, callOptions: callOptions)).vms.installedAgent))

		guard reply.success else {
			throw ServiceError(reply.reason)
		}

		return reply
	}

	// MARK: version
	struct Version: GrpcParsableCommand {
		static let configuration = CommandConfiguration(commandName: "version", abstract: String(localized: "Show the version of the agent running in a VM"))

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "VM name")))
		var name: String

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			self.options.format.render(try Agent.version(client: client, name: self.name, interrupt: Interrupt(), callOptions: callOptions))
		}
	}

	// MARK: install
	struct Install: GrpcParsableCommand {
		static let configuration = CommandConfiguration(commandName: "install", abstract: String(localized: "Install the agent in a running VM"))

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "VM name")))
		var name: String

		@Option(name: [.customLong("ssh-timeout")], help: ArgumentHelp(String(localized: "Seconds to wait for the guest's SSH server")))
		var sshTimeout: UInt = AgentHandler.defaultInstallTimeout

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			self.options.format.render(try Agent.install(client: client, name: self.name, sshTimeout: self.sshTimeout, interrupt: Interrupt(), callOptions: callOptions))
		}
	}

	// MARK: update
	struct Update: GrpcParsableCommand {
		static let configuration = CommandConfiguration(commandName: "update", abstract: String(localized: "Install the agent in a running VM unless it is already up to date"))

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "VM name")))
		var name: String

		@Flag(name: [.customLong("force")], help: ArgumentHelp(String(localized: "Install even if the agent already runs this version")))
		var force: Bool = false

		@Option(name: [.customLong("ssh-timeout")], help: ArgumentHelp(String(localized: "Seconds to wait for the guest's SSH server")))
		var sshTimeout: UInt = AgentHandler.defaultInstallTimeout

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let interrupt = Interrupt()
			let current = try Agent.version(client: client, name: self.name, interrupt: interrupt, callOptions: callOptions)

			guard AgentHandler.updateIsNeeded(current, force: self.force) else {
				return self.options.format.render(AgentHandler.upToDate(current))
			}

			return self.options.format.render(try Agent.install(client: client, name: self.name, sshTimeout: self.sshTimeout, interrupt: interrupt, callOptions: callOptions))
		}
	}
}
