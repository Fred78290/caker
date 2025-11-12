import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import SwiftUI

struct Umount: GrpcParsableCommand {
	static let configuration = UmountOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Umount options")
	var umount: UmountOptions

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.umount(Caked_MountRequest(command: self), callOptions: callOptions).response.wait().mounts)
	}
}
