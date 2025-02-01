import ArgumentParser
import Foundation
import GRPC
import CakeAgentLib
import NIO

final class Exec: CakeAgentAsyncParsableCommand {
	static var configuration: CommandConfiguration = CommandConfiguration(commandName: "exec", abstract: "Execute a command on a VM")

	@Argument(help: "VM name")
	var name: String

	@OptionGroup
	var options: CakeAgentClientOptions

	@Argument(help: "Command to execute")
	var arguments: [String]

	func validate() throws {
		if arguments.count < 1 {
			throw ValidationError("At least one argument is required")
		}
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		let command = self.arguments.remove(at: 0)
		let exitCode = try await CakeAgentHelper(on: on, client: client).exec(command: command, arguments: self.arguments, callOptions: callOptions)

		if exitCode != 0 {
			throw ServiceError("exec failed", exitCode)
		}
	}
}
