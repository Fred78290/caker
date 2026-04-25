import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
@preconcurrency import GRPC
import GRPCLib
import NIO

struct Sh: CakeAgentAsyncParsableCommand {
	
	static let configuration = ShellOptions.configuration

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@OptionGroup(title: String(localized: "override client agent options"), visibility: .hidden)
	var options: CakeAgentClientOptions

	@OptionGroup(title: String(localized: "Shell options"))
	var shell: ShellOptions

	var createVM: Bool = false

	var logLevel: Logger.LogLevel {
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

		if self.shell.name == String.empty {
			self.shell.name = GetOptions.primaryName

			self.createVM = StorageLocation(runMode: self.common.runMode).exists(self.shell.name) == false
		}

		try self.validateOptions(runMode: self.common.runMode)
	}

	func run(on: EventLoopGroup, helper: CakeAgentHelper, callOptions: CallOptions?) async throws {
		if self.createVM {
			let build = await CakedLib.BuildHandler.build(options: .init(name: self.shell.name), runMode: self.common.runMode, progressHandler: ProgressObserver.progressHandler)

			guard build.builded else {
				Logger.appendNewLine(build.reason)
				return
			}
		}

		guard let result = try? CakedLib.StartHandler.startVM(name: self.shell.name, screenSize: nil, vncPassword: nil, vncPort: nil, waitIPTimeout: self.shell.waitIPTimeout, startMode: self.shell.foreground ? .foreground : .background, gcd: false, recoveryMode: false, runMode: self.common.runMode) else {
			Logger.appendNewLine(self.common.format.render("Failed to start VM"))

			return
		}

		if result.started {
			do {
				_ = try await helper.shell(callOptions: callOptions)
			} catch {
				Logger.appendNewLine(self.common.format.render(error.reason))
			}
		} else {
			Logger.appendNewLine(self.common.format.render(result.reason))
		}
	}
}
