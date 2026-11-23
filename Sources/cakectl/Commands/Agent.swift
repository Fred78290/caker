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

	/// The agent version a running VM reports, through the connected caked's `Info` call.
	static func version(client: CakedServiceClient, name: String, callOptions: CallOptions?) throws -> AgentVersionReply {
		let reply = try client.info(.with { $0.name = name }, callOptions: callOptions).response.wait().vms.status

		guard reply.success else {
			throw ServiceError(reply.reason)
		}

		return AgentVersionReply(name: name, running: VMInformations(reply.infos).status == .running, version: reply.infos.agentVersion)
	}

	/// Asks the connected caked to install the agent, and fails the command when it could not.
	static func install(client: CakedServiceClient, name: String, sshTimeout: UInt, callOptions: CallOptions?) throws -> AgentInstallReply {
		let reply = AgentInstallReply(InstalledAgentReply(try client.installAgent(.with {
			$0.name = name
			$0.timeout = Int32(clamping: sshTimeout)
		}, callOptions: callOptions).response.wait().vms.installedAgent))

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
			self.options.format.render(try Agent.version(client: client, name: self.name, callOptions: callOptions))
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
			self.options.format.render(try Agent.install(client: client, name: self.name, sshTimeout: self.sshTimeout, callOptions: callOptions))
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
			let current = try Agent.version(client: client, name: self.name, callOptions: callOptions)

			guard AgentHandler.updateIsNeeded(current, force: self.force) else {
				return self.options.format.render(AgentHandler.upToDate(current))
			}

			return self.options.format.render(try Agent.install(client: client, name: self.name, sshTimeout: self.sshTimeout, callOptions: callOptions))
		}
	}
}
