import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC

struct Mount: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "mount", abstract: "Mount directory share into VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String = ""

	@Option(name: .shortAndLong, help: "Output format: text or json")
	var format: Format = .text

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Additional directory shares\n", discussion: mount_help))
	var mounts: [DirectorySharingAttachment] = []

	mutating public func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}
	}

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.mount(Caked_MountRequest(command: self), callOptions: callOptions).response.wait()
	}
}
