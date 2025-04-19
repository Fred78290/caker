import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC

struct Mount: GrpcParsableCommand {
	static let configuration = CommandConfiguration(commandName: "mount", abstract: "Mount directory share into VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String = ""

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Additional directory shares\n", discussion: mount_help))
	var mounts: [DirectorySharingAttachment] = []

	mutating public func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}
	}

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.format.render(try client.mount(Caked_MountRequest(command: self), callOptions: callOptions).response.wait().successfull().mounts)
	}
}
