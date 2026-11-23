import ArgumentParser
import Foundation
import Logging
import GRPC
import GRPCLib

struct Exec: GrpcParsableCommand {
	static let configuration = ExecOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Exec options"))
	var execute: ExecOptions

	@Option(name: .customLong("seamless"), help: ArgumentHelp(String(localized: "Allows seamless mode if the VM supports it")))
	var allowSeamless: Bool = true

	var interceptors: Caked_ServiceClientInterceptorFactoryProtocol? {
		try? CakeServiceClientInterceptorFactory(inputHandle: FileHandle.standardInput)
	}

	static var disableLoggingOutput = false

	func logHandler(_ label: String) -> LogHandler {
		if Self.disableLoggingOutput {
			SwiftLogNoOpLogHandler()
		} else {
			StreamLogHandler.standardError(label: label)
		}
	}

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let config = try client.info(name: self.execute.name, includeConfig: true).vms.status.config

		if config.seamless && allowSeamless {
			Self.disableLoggingOutput = true

			let name = self.execute.name
			let terminal = Sh.saveTerminal()

			// The seamless task blocks the main thread in NSApplication.run(), so a task group
			// can't cancel it (the group waits for every child). Whichever side ends first
			// ends the process instead, which kills the other one.
			let shellTask = Task {
				do {
					Sh.exit(try await client.exec(name: self.execute.name, shellUser: self.execute.shellUser, command: self.execute.arguments.first!, arguments: self.execute.arguments.dropFirst().map { $0 }, callOptions: callOptions), restoring: terminal)
				} catch {
					fputs("Error: \(error)\n", stderr)
					Sh.exit(1, restoring: terminal)
				}
			}

			// Returns once the seamless windows are closed
			// ArgumentParser runs the command on the main thread
			try MainActor.assumeIsolated {
				try Sh.seamless(name, client: client, terminal: terminal)
			}

			shellTask.cancel()
			Sh.exit(0, restoring: terminal)
		} else {
			try Task.sync {
				Foundation.exit(try await client.exec(name: self.execute.name, shellUser: self.execute.shellUser, command: self.execute.arguments.first!, arguments: self.execute.arguments.dropFirst().map { $0 }, callOptions: callOptions))
			}
		}
	}
}
