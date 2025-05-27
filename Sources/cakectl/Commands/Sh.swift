import ArgumentParser
import Foundation
@preconcurrency import GRPC
import GRPCLib
import NIO
import NIOPosix
import NIOSSL

struct Sh: AsyncGrpcParsableCommand {
	static let configuration = ShellOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Shell options")
	var shell: ShellOptions

	var interceptors: Caked_ServiceClientInterceptorFactoryProtocol? {
		try? CakeAgentClientInterceptorFactory(inputHandle: FileHandle.standardInput)
	}

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		Foundation.exit(try await client.shell(name: self.shell.name, callOptions: callOptions))
	}
}
