import ArgumentParser
import Dispatch
import Foundation
import GRPC
import GRPCLib
import TextTable
import CakeAgentLib

struct Duplicate: AsyncGrpcParsableCommand {
	static let configuration = DuplicateOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Duplicate options"))
	var duplicate: DuplicateOptions

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		let taskID = UUID()

		// Ctrl-C asks caked to cancel: it kills and deletes the temporary VM, then answers "Cancelled".
		return try await Client.cancellingTaskOnInterrupt(
			client: client, callOptions: callOptions, taskID: taskID,
			succeeded: { $0.vms.duplicated.duplicated },
			render: { self.options.format.render($0.vms.duplicated) }
		) {
			try await client.duplicate(Caked_DuplicateRequest(command: self, taskID: taskID), callOptions: callOptions).response.get()
		}
	}
}
