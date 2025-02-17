import ArgumentParser
import Foundation
import GRPC
import CakeAgentLib
import NIO
import Logging

struct Exec: CakeAgentAsyncParsableCommand {
	static var configuration: CommandConfiguration = CommandConfiguration(commandName: "exec", abstract: "Execute a command on a VM")

	@Argument(help: "VM name")
	var name: String

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@OptionGroup
	var options: CakeAgentClientOptions

	@Argument(help: "Command to execute")
	var arguments: [String]

	@Flag(help: .hidden)
	var foreground: Bool = false

	@Option(help:"Maximum of seconds to getting IP")
	var waitIPTimeout = 180

	mutating func validate() throws {
		Logger.setLevel(self.logLevel)

		if arguments.count < 1 {
			throw ValidationError("At least one argument is required")
		}

		try validateOptions()
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		try startVM(on: on.next(), waitIPTimeout: self.waitIPTimeout, foreground: self.foreground)

		var arguments = self.arguments
		let command = arguments.remove(at: 0)
		let exitCode = try CakeAgentHelper(on: on, client: client).exec(command: command, arguments: arguments, callOptions: callOptions)

		if exitCode != 0 {
			throw ServiceError("exec failed", exitCode)
		}
	}
}
