import ArgumentParser
@preconcurrency import GRPC
import CakeAgentLib
import Foundation
import NIO
import Logging

struct Sh: CakeAgentAsyncParsableCommand {	
	static let configuration = CommandConfiguration(commandName: "shell", abstract: "Run a shell on a VM")

	@Flag(name: [.customLong("system"), .customShort("s")], help: "Act as system agent, need sudo")
	var asSystem: Bool = false

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
		if self.name == "" {
			self.name = "primary"

			self.createVM = StorageLocation(asSystem: self.asSystem).exists(self.name) == false
		}

		try self.validateOptions(asSystem: self.asSystem)
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		if self.createVM {
			try await BuildHandler.build(name: self.name, options: .init(name: self.name), asSystem: self.asSystem)
		}

		try startVM(on: on.next(), waitIPTimeout: self.waitIPTimeout, foreground: self.foreground, asSystem: self.asSystem)
		_ = try await CakeAgentHelper(on: on, client: client).shell(callOptions: callOptions)
	}
}
