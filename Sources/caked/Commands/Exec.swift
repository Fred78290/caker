import ArgumentParser
import Foundation
import GRPC
import CakeAgentLib
import NIO
import Logging

struct Exec: CakeAgentAsyncParsableCommand {
	static let configuration: CommandConfiguration = CommandConfiguration(commandName: "exec", abstract: "Execute a command on a VM")

	@Argument(help: "VM name")
	var name: String

	@OptionGroup var common: CommonOptions

	@OptionGroup(title: "override client agent options", visibility: .hidden)
	var options: CakeAgentClientOptions

	@Argument(help: "Command to execute")
	var arguments: [String]

	@Flag(help: .hidden)
	var foreground: Bool = false

	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
	var waitIPTimeout = 180

    var createVM: Bool = false

	var logLevel: Logging.Logger.Level {
		self.common.logLevel
	}

	var asSystem: Bool {
		self.common.asSystem
	}

	var interceptors: Cakeagent_AgentClientInterceptorFactoryProtocol? {
		CakeAgentLib.CakeAgentClientInterceptorFactory(inputHandle: FileHandle.standardInput) { method in
			// We need to cancel the signal source for SIGINT when we are in the exec command
			if method == Cakeagent_AgentClientMetadata.Methods.execute || method == Cakeagent_AgentClientMetadata.Methods.run {
				// This is a workaround for the fact that we can't cancel the signal source in the interceptor
				// because it is not thread safe. So we cancel it here and then we can safely exit.
				Root.sigintSrc.cancel()
			}
			return true
		}
	}

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		if arguments.count < 1 {
			throw ValidationError("At least one argument is required")
		}

		try validateOptions(asSystem: self.common.asSystem)
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		try startVM(on: on.next(), waitIPTimeout: self.waitIPTimeout, foreground: self.foreground, asSystem: self.common.asSystem)

		var arguments = self.arguments
		let command = arguments.remove(at: 0)
		let exitCode = try await CakeAgentHelper(on: on, client: client).exec(command: command, arguments: arguments, callOptions: callOptions)

		if exitCode != 0 {
			throw ServiceError("exec failed", exitCode)
		}
	}
}
