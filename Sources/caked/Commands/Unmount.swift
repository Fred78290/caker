import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
@preconcurrency import GRPC
import GRPCLib
import NIO

struct Umount: ParsableCommand {
	static let configuration = UmountOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Umount options")
	var umount: UmountOptions

	@Flag(help: ArgumentHelp("Service endpoint", discussion: "This option allow mode to connect to a running service", visibility: .hidden))
	var mode: VMRunServiceMode = .grpc

	public func validate() throws {
		Logger.setLevel(self.common.logLevel)

		let location = try StorageLocation(runMode: self.common.runMode).find(self.umount.name)
		let config = try location.config()
		let directorySharingAttachments = config.mounts

		try self.umount.mounts.forEach { attachment in
			let description = attachment.description

			if directorySharingAttachments.contains(where: { $0.description == description }) == false {
				throw ValidationError("Mount \(description) does not exist")
			}
		}
	}

	func run() throws {
		let location = try StorageLocation(runMode: self.common.runMode).find(self.umount.name)
		let result = CakedLib.MountHandler.Umount(mode, location: location, mounts: self.umount.mounts, runMode: self.common.runMode)

		if result.success {
			Logger.appendNewLine(self.common.format.render(result.mounts))
		} else {
			Logger.appendNewLine(self.common.format.render(result.reason))
		}
	}

}
