import ArgumentParser
@preconcurrency import GRPC
import CakeAgentLib
import Foundation
import NIO

final class Sh: CakeAgentAsyncParsableCommand {
	static var configuration = CommandConfiguration(commandName: "shell", abstract: "Run a shell on a VM")

	@Argument(help: "VM name")
	var name: String

	@OptionGroup
	var options: CakeAgentClientOptions

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		try await CakeAgentHelper(on: on, client: client).shell(callOptions: callOptions)
	}
}
