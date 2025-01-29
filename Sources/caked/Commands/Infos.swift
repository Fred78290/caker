import ArgumentParser
import Foundation
import NIO
import GRPC
import CakeAgentLib

final class Infos: CakeAgentAsyncParsableCommand {
	static var configuration: CommandConfiguration = CommandConfiguration(commandName: "infos", abstract: "Get info for VM")

	@Argument(help: "VM name")
	var name: String

	@OptionGroup
	var options: CakeAgentClientOptions

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		print(try await CakeAgentHelper(on: on, client: client).info(callOptions: callOptions))
	}
}