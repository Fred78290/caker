import ArgumentParser
import Foundation
import NIO
import GRPC
import GRPCLib
import CakeAgentLib

final class Infos: CakeAgentAsyncParsableCommand {
	static var configuration: CommandConfiguration = CommandConfiguration(commandName: "infos", abstract: "Get info for VM")

	@Argument(help: "VM name")
	var name: String

	@Option(help: "Output format: text or json")
	var format: Format = .text

	@OptionGroup
	var options: CakeAgentClientOptions

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		let result = try await CakeAgentHelper(on: on, client: client).info(callOptions: callOptions)

		Logger.appendNewLine(format.renderSingle(result))
	}
}
