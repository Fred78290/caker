import ArgumentParser
import Foundation
@preconcurrency import GRPC
import GRPCLib
import CakeAgentLib
import Logging
import NIO
import TextTable

struct Umount: ParsableCommand {
	static var configuration = CommandConfiguration(commandName: "umount", abstract: "Unmount a directory share from a VM")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Argument(help: "VM name")
	var name: String = ""

	@Option(name: .shortAndLong, help: "Output format")
	var format: Format = .text

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Give host path to umount", discussion: "Remove directory shares. If omitted all mounts will be removed from the named vm" ))
	var mounts: [DirectorySharingAttachment] = []

	mutating public func validate() throws {

		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		let vmLocation = try StorageLocation(asSystem: runAsSystem).find(self.name)
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
		let vmLocation = try StorageLocation(asSystem: runAsSystem).find(self.name)
		let response = try MountHandler.Umount(vmLocation: vmLocation, mounts: self.mounts)

		print(format.renderList(style: Style.grid, uppercased: true, response.mounts.map { MountHandler.MountVirtioFSReply($0) }))
	}

}
