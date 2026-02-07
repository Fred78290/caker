import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Exec: AsyncGrpcParsableCommand {
	static let configuration = ExecOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Exec options")
	var execute: ExecOptions

	var interceptors: Caked_ServiceClientInterceptorFactoryProtocol? {
		try? CakeServiceClientInterceptorFactory(inputHandle: FileHandle.standardInput)
	}

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		Foundation.exit(try await client.exec(name: self.execute.name, command: self.execute.arguments.first!, arguments: self.execute.arguments.dropFirst().map { $0 }, callOptions: callOptions))
	}
}
