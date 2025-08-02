import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
@preconcurrency import GRPC
import GRPCLib
import Logging
import NIO

struct Sh: CakeAgentAsyncParsableCommand {
	static let configuration = ShellOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "override client agent options", visibility: .hidden)
	var options: CakeAgentClientOptions

	@OptionGroup(title: "Shell options")
	var shell: ShellOptions

	var createVM: Bool = false

	var logLevel: Logging.Logger.Level {
		self.common.logLevel
	}

	var runMode: Utils.RunMode {
		self.common.runMode
	}

	var name: String {
		self.shell.name
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

		if self.shell.name == "" {
			self.shell.name = "primary"

			self.createVM = StorageLocation(runMode: self.common.runMode).exists(self.shell.name) == false
		}

		try self.validateOptions(runMode: self.common.runMode)
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		if self.createVM {
			try await CakedLib.BuildHandler.build(name: self.shell.name, options: .init(name: self.shell.name), runMode: self.common.runMode, progressHandler: ProgressObserver.progressHandler)
		}

		try startVM(on: on.next(), name: self.shell.name, waitIPTimeout: self.shell.waitIPTimeout, foreground: self.shell.foreground, runMode: self.common.runMode)
		_ = try await CakeAgentHelper(on: on, client: client).shell(callOptions: callOptions)
	}
}
