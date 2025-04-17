import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Exec: AsyncGrpcParsableCommand {
	static let configuration = CommandConfiguration(commandName: "exec", abstract: "Run a shell command in a VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String

	@Argument(help: "Command to execute")
	var arguments: [String]

	func validate() throws {
		if arguments.isEmpty {
			throw ValidationError("No command specified")
		}
	}

	var interceptors: Caked_ServiceClientInterceptorFactoryProtocol? {
		CakeAgentClientInterceptorFactory(inputHandle: FileHandle.standardInput)
	}

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		Foundation.exit(try await client.exec(name: self.name, command: self.arguments.first!, arguments: self.arguments.dropFirst().map { $0 }, callOptions: callOptions))
	}
}
