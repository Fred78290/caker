import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib

/// `caked agent version|install|update <vm>`: the cakeagent of a VM, managed from the command line (Caker.app's
/// "Install agent"/"Update agent" button does the same).
struct Agent: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "agent",
		abstract: String(localized: "Show, install or update the cakeagent of a virtual machine"),
		discussion: String(localized: "The VM must be running. 'version' asks the agent which version it runs, 'install' always installs this build's agent over SSH, 'update' installs it only when the guest runs another version."),
		subcommands: [Version.self, Install.self, Update.self]
	)

	// MARK: version
	struct Version: ParsableCommand {
		static let configuration = CommandConfiguration(commandName: "version", abstract: String(localized: "Show the version of the agent running in a VM"))

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@Argument(help: ArgumentHelp(String(localized: "VM name")))
		var name: String

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			Logger.appendNewLine(self.common.format.render(AgentHandler.version(name: self.name, runMode: self.common.runMode)))
		}
	}

	// MARK: install
	struct Install: ParsableCommand {
		static let configuration = CommandConfiguration(commandName: "install", abstract: String(localized: "Install the agent in a running VM"))

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@Argument(help: ArgumentHelp(String(localized: "VM name")))
		var name: String

		@Option(name: [.customLong("ssh-timeout")], help: ArgumentHelp(String(localized: "Seconds to wait for the guest's SSH server")))
		var sshTimeout: UInt = AgentHandler.defaultInstallTimeout

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			let reply = AgentHandler.install(name: self.name, timeout: self.sshTimeout, runMode: self.common.runMode)

			Logger.appendNewLine(self.common.format.render(reply))

			if reply.success == false {
				throw ExitCode.failure
			}
		}
	}

	// MARK: update
	struct Update: ParsableCommand {
		static let configuration = CommandConfiguration(commandName: "update", abstract: String(localized: "Install the agent in a running VM unless it is already up to date"))

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@Argument(help: ArgumentHelp(String(localized: "VM name")))
		var name: String

		@Flag(name: [.customLong("force")], help: ArgumentHelp(String(localized: "Install even if the agent already runs this version")))
		var force: Bool = false

		@Option(name: [.customLong("ssh-timeout")], help: ArgumentHelp(String(localized: "Seconds to wait for the guest's SSH server")))
		var sshTimeout: UInt = AgentHandler.defaultInstallTimeout

		func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			let reply = AgentHandler.update(name: self.name, force: self.force, timeout: self.sshTimeout, runMode: self.common.runMode)

			Logger.appendNewLine(self.common.format.render(reply))

			if reply.success == false {
				throw ExitCode.failure
			}
		}
	}
}
