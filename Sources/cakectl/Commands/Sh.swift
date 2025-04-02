import ArgumentParser
import Foundation
import GRPCLib
@preconcurrency import GRPC
import NIO
import NIOPosix
import NIOSSL

struct Sh: AsyncGrpcParsableCommand {
	static let configuration = CommandConfiguration(commandName: "shell", abstract: "Run a shell on a VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String = ""

	var interceptors: Caked_ServiceClientInterceptorFactoryProtocol? {
		CakeAgentClientInterceptorFactory(inputHandle: FileHandle.standardInput)
	}

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) async throws -> Caked_Reply {
		Foundation.exit(try await client.shell(name: name, callOptions: callOptions))
	}
}
