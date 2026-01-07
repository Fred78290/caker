import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
@preconcurrency import GRPC
import GRPCLib
import NIO

struct Mount: ParsableCommand {
	static let configuration = MountOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Mount options")
	var mount: MountOptions

	@Flag(help: ArgumentHelp("Service endpoint", discussion: "This option allow mode to connect to a running service", visibility: .hidden))
	var mode: VMRunServiceMode = .grpc

	func validate() throws {
		Logger.setLevel(self.common.logLevel)

		let location = try StorageLocation(runMode: self.common.runMode).find(self.mount.name)
		let config: CakeConfig = try location.config()
		let directorySharingAttachments = config.mounts

		try self.mount.mounts.forEach { attachment in
			let description = attachment.description

			if directorySharingAttachments.contains(where: { $0.description == description }) {
				throw ValidationError("Mount \(description) already exists")
			}
		}
	}

	func run() throws {
		let location = try StorageLocation(runMode: self.common.runMode).find(self.mount.name)
		let result = CakedLib.MountHandler.Mount(mode, location: location, mounts: self.mount.mounts, runMode: self.common.runMode)

		if result.success {
			Logger.appendNewLine(self.common.format.render(result.mounts))
		} else {
			Logger.appendNewLine(self.common.format.render(result.reason))
		}
	}
}
