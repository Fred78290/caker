import ArgumentParser
import Foundation
@preconcurrency import GRPC
import GRPCLib
import CakeAgentLib
import Logging
import NIO
import TextTable

struct Mount: ParsableCommand {
	static let configuration = CommandConfiguration(commandName: "mount", abstract: "Mount directory share into VM")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Argument(help: "VM name")
	var name: String = ""

	@Option(name: .shortAndLong, help: "Output format")
	var format: Format = .text

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Additional directory shares", discussion: mount_help))
	var mounts: [DirectorySharingAttachment] = []

	mutating public func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		let vmLocation = try StorageLocation(asSystem: runAsSystem).find(self.name)
		let config: CakeConfig = try vmLocation.config()
		let directorySharingAttachments = config.mounts

		try self.mounts.forEach { attachment in
			let description = attachment.description

			if directorySharingAttachments.contains(where: { $0.description == description }) {
				throw ValidationError("Mount \(description) already exists")
			}
		}
	}

	func run() throws {
		let vmLocation = try StorageLocation(asSystem: runAsSystem).find(self.name)
		let response = try MountHandler.Mount(vmLocation: vmLocation, mounts: self.mounts)

		Logger.appendNewLine(self.format.render(response))

		if case let .error(error) = response.response {
			FileHandle.standardError.write("\(error)\n".data(using: .utf8)!)
			Foundation.exit(EXIT_FAILURE)
		}
	}
}
