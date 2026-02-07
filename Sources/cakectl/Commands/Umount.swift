import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI
import CakeAgentLib

struct Umount: GrpcParsableCommand {
	static let configuration = UmountOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Umount options")
	var umount: UmountOptions

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.umount(Caked_MountRequest(command: self), callOptions: callOptions).response.wait().mounts

		if result.success {
			return self.format.render(result.mounts)
		} else {
			return self.format.render(result.reason)
		}
	}
}
