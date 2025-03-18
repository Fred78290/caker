import ArgumentParser
import Dispatch
import SwiftUI
import GRPCLib
import GRPC

struct Umount: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "mount", abstract: "Mount endpoint into VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String = ""

	@Option(name: .shortAndLong, help: "Output format: text or json")
	var format: Format = .text

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Give host path to umount", discussion: "Remove directory shares. If omitted all mounts will be removed from the named vm" ))
	var mounts: [DirectorySharingAttachment] = []

	mutating public func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}
	}

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		return try client.umount(Caked_MountRequest(command: self), callOptions: callOptions).response.wait()
	}
}
