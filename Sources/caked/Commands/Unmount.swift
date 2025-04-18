import ArgumentParser
import Foundation
@preconcurrency import GRPC
import GRPCLib
import CakeAgentLib
import Logging
import NIO
import TextTable

struct Umount: ParsableCommand {
	static let configuration = CommandConfiguration(commandName: "umount", abstract: "Unmount a directory share from a VM")

	@OptionGroup var common: CommonOptions

	@Argument(help: "VM name")
	var name: String = ""

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Give host path to umount", discussion: "Remove directory shares. If omitted all mounts will be removed from the named vm" ))
	var mounts: [DirectorySharingAttachment] = []

	mutating public func validate() throws {
		Logger.setLevel(self.common.logLevel)

		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		let vmLocation = try StorageLocation(asSystem: self.common.asSystem).find(self.name)
		let config = try vmLocation.config()
		let directorySharingAttachments = config.mounts

		try self.mounts.forEach { attachment in
			let description = attachment.description

			if directorySharingAttachments.contains(where: { $0.description == description }) == false {
				throw ValidationError("Mount \(description) does not exist")
			}
		}
	}

	func run() throws {
		let vmLocation = try StorageLocation(asSystem: self.common.asSystem).find(self.name)
		let response = try MountHandler.Umount(vmLocation: vmLocation, mounts: self.mounts)

		Logger.appendNewLine(self.common.format.render(response))

		if case let .error(error) = response.response {
			FileHandle.standardError.write("\(error)\n".data(using: .utf8)!)
			Foundation.exit(EXIT_FAILURE)
		}
	}

}
