import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO

struct Exec: CakeAgentAsyncParsableCommand {
	static let configuration = ExecOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Exec options")
	var execute: ExecOptions

	@OptionGroup(title: "override client agent options", visibility: .hidden)
	var options: CakeAgentClientOptions

	var createVM: Bool = false

	var logLevel: Logger.LogLevel {
		self.common.logLevel
	}

	var runMode: Utils.RunMode {
		self.common.runMode
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
		try self.validateOptions(runMode: self.common.runMode)
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async {
		guard let result = try? CakedLib.StartHandler.startVM(name: self.execute.name, screenSize: nil, vncPassword: nil, vncPort: nil, waitIPTimeout: self.execute.waitIPTimeout, startMode: self.execute.foreground ? .foreground : .background, runMode: self.common.runMode) else {
			Logger.appendNewLine(self.common.format.render("Failed to start VM"))

			return
		}

		if result.started {
			var arguments = self.execute.arguments
			let command = arguments.remove(at: 0)

			do {
				let exitCode = try await CakeAgentHelper(on: on, client: client).exec(command: command, arguments: arguments, callOptions: callOptions)

				if exitCode != 0 {
					throw CakedLib.ExitCode(exitCode)
				}
			} catch {
				Logger.appendNewLine(self.common.format.render("\(error)"))
			}
		} else {
			Logger.appendNewLine(self.common.format.render(result.reason))
		}
	}
}
