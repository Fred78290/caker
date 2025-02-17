import ArgumentParser
@preconcurrency import GRPC
import CakeAgentLib
import Foundation
import NIO
import Logging

struct Sh: CakeAgentAsyncParsableCommand {
	static var configuration = CommandConfiguration(commandName: "shell", abstract: "Run a shell on a VM")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Argument(help: "VM name")
	var name: String

	@OptionGroup
	var options: CakeAgentClientOptions

	@Flag(help: .hidden)
	var foreground: Bool = false

	@Option(help:"Maximum of seconds to getting IP")
	var waitIPTimeout = 180

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		try startVM(on: on.next(), waitIPTimeout: self.waitIPTimeout, foreground: self.foreground)
		try await CakeAgentHelper(on: on, client: client).shell(callOptions: callOptions)
	}
}
