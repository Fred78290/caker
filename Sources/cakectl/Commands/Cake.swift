//
//
//  Created by Frederic BOLTZ on 22/11/2024.
//
import ArgumentParser
import Foundation
import GRPC
import GRPCLib

struct Cake: GrpcParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Catch all tart commands", shouldDisplay: false)

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Argument(help: "command")
	var command: String?

	init() {

	}

	init(command: String?) {
		self.command = command
	}

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return try client.cakeCommand(Caked_CakedCommandRequest(command: self.command ?? "", arguments: arguments), callOptions: callOptions).response.wait().tart.message
	}
}
