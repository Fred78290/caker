import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Exec: AsyncGrpcParsableCommand {
	static let configuration = ExecOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Exec options"))
	var execute: ExecOptions

	var interceptors: Caked_ServiceClientInterceptorFactoryProtocol? {
		try? CakeServiceClientInterceptorFactory(inputHandle: FileHandle.standardInput)
	}

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		let config = try client.info(name: self.execute.name, includeConfig: true).vms.status.config

		if config.seamless {
			let name = self.execute.name

			// The seamless task blocks the main thread in NSApplication.run(), so a task group
			// can't cancel it (the group waits for every child). Whichever side ends first
			// ends the process instead, which kills the other one.
			let shellTask = Task {
				do {
					Foundation.exit(try await client.exec(name: self.execute.name, command: self.execute.arguments.first!, arguments: self.execute.arguments.dropFirst().map { $0 }, callOptions: callOptions))
				} catch {
					fputs("Error: \(error)\n", stderr)
					Foundation.exit(1)
				}
			}

			// Returns once the seamless windows are closed
			try await Sh.seamless(name, client: client)

			shellTask.cancel()
			Foundation.exit(0)
		} else {
			Foundation.exit(try await client.exec(name: self.execute.name, command: self.execute.arguments.first!, arguments: self.execute.arguments.dropFirst().map { $0 }, callOptions: callOptions))
		}
	}
}
