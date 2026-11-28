import ArgumentParser
import Compression
import Dispatch
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Push: AsyncGrpcParsableCommand {
	static let configuration = PushOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Push options"))
	var push: PushOptions

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		let taskID = UUID()

		// Ctrl-C asks caked to cancel: it kills and deletes the temporary VM, or stops the upload.
		let reply = try await Client.cancellingTaskOnInterrupt(client: client, callOptions: callOptions, taskID: taskID) {
			try await client.push(Caked_PushRequest(command: self, taskID: taskID), callOptions: callOptions).response.get()
		}

		return self.options.format.render(reply.oci.push)
	}
}
