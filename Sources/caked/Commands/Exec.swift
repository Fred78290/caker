import ArgumentParser
import Foundation
import GRPC
import CakeAgentLib
import NIO
import Logging
import GRPCLib

struct Exec: CakeAgentAsyncParsableCommand {
	static let configuration = ExecOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Exec options")
	var execute: ExecOptions

	@OptionGroup(title: "override client agent options", visibility: .hidden)
	var options: CakeAgentClientOptions

	var createVM: Bool = false

	var logLevel: Logging.Logger.Level {
		self.common.logLevel
	}

	var asSystem: Bool {
		self.common.asSystem
	}

	var name: String {
		self.execute.name
	}

	var interceptors: CakeAgentServiceClientInterceptorFactoryProtocol? {
		try? CakeAgentLib.CakeAgentClientInterceptorFactory(inputHandle: FileHandle.standardInput) { method in
			// We need to cancel the signal source for SIGINT when we are in the exec command
			if method == CakeAgentServiceClientMetadata.Methods.execute || method == CakeAgentServiceClientMetadata.Methods.run {
				// This is a workaround for the fact that we can't cancel the signal source in the interceptor
				// because it is not thread safe. So we cancel it here and then we can safely exit.
				Root.sigintSrc.cancel()
			}
			return true
		}
	}

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)
		try self.validateOptions(asSystem: self.common.asSystem)
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		try startVM(on: on.next(), name: self.execute.name, waitIPTimeout: self.execute.waitIPTimeout, foreground: self.execute.foreground, asSystem: self.common.asSystem)

		var arguments = self.execute.arguments
		let command = arguments.remove(at: 0)
		let exitCode = try await CakeAgentHelper(on: on, client: client).exec(command: command, arguments: arguments, callOptions: callOptions)

		if exitCode != 0 {
			throw ExitCode(exitCode)
		}
	}
}
