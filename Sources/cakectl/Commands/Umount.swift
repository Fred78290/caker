import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI
import CakeAgentLib

struct Umount: GrpcParsableCommand {
	static let configuration = UmountOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Umount options"))
	var umount: UmountOptions

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.umount(Caked_MountRequest(command: self), callOptions: callOptions).response.wait().mounts

		if result.success {
			return self.options.format.render(result.mounts)
		} else {
			return self.options.format.render(result.reason)
		}
	}
}
