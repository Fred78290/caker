import ArgumentParser
@preconcurrency import GRPC
import CakeAgentLib
import Foundation
import NIO
import Logging

struct Sh: CakeAgentAsyncParsableCommand {
	static let configuration = CommandConfiguration(commandName: "shell", abstract: "Run a shell on a VM")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Argument(help: "VM name")
	var name: String = ""

	@OptionGroup(title: "override client agent options", visibility: .hidden)
	var options: CakeAgentClientOptions

	@Flag(help: .hidden)
	var foreground: Bool = false

	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
	var waitIPTimeout = 180

	var createVM: Bool = false

	var interceptors: Cakeagent_AgentClientInterceptorFactoryProtocol? {
		CakeAgentLib.CakeAgentClientInterceptorFactory(inputHandle: FileHandle.standardInput)
	}

	mutating func validate() throws {
		if self.name == "" {
			self.name = "primary"

			self.createVM = StorageLocation(asSystem: runAsSystem).exists(self.name) == false
		}

		try self.validateOptions()
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		if self.createVM {
			try await BuildHandler.build(name: self.name, options: .init(name: self.name), asSystem: false)
		}

		try startVM(on: on.next(), waitIPTimeout: self.waitIPTimeout, foreground: self.foreground)
		_ = try await CakeAgentHelper(on: on, client: client).shell(callOptions: callOptions)
	}
}
