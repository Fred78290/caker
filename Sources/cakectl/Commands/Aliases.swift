import ArgumentParser
import CakedLib
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Aliases: GrpcParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "aliases",
		abstract: String(localized: "List catalog image ids usable with build/launch --alias"),
		discussion: String(localized: "Lists every id from the connected caked's VMImages.json for its architecture, e.g. macos12, ubuntu2604, fedora44Server.")
	)

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let reply = try client.aliases(Caked_Empty(), callOptions: callOptions).response.wait().aliases

		return self.options.format.render(reply.aliases.map { VMImageAliasEntry($0) })
	}
}
