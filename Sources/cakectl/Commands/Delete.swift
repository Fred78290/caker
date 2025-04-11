import ArgumentParser
import Dispatch
import GRPCLib
import GRPC
import TextTable

struct Delete: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Delete a VM")

	struct DeleteReply: Codable {
		let source: String
		let name: String
		let deleted: Bool
	}

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: [String]

	@Option(name: .shortAndLong, help: "Output format")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		format.renderList(style: Style.grid, uppercased: true, try client.delete(Caked_DeleteRequest(command: self), callOptions: callOptions).response.wait().successfull().vms.delete.objects.map {
			DeleteReply(source: $0.source, name: $0.name, deleted: $0.deleted)
		})
	}
}
