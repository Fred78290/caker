import ArgumentParser
import Foundation
import GRPCLib
import GRPC
import TextTable
import CakeAgentLib

struct Infos: GrpcParsableCommand {
	static let configuration = CommandConfiguration(commandName: "infos", abstract: "Get info for VM")

	@OptionGroup var options: Client.Options

	@Option(name: .shortAndLong, help: "Output format: text or json")
	var format: Format = .text

	@Argument(help: "VM name")
	var name: String

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.info(Caked_InfoRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.infos)
	}
}
