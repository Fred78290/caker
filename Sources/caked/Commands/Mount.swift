import ArgumentParser
import CakeAgentLib
import Foundation
@preconcurrency import GRPC
import GRPCLib
import Logging
import NIO
import CakedLib

struct Mount: ParsableCommand {
	static let configuration = MountOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Mount options")
	var mount: MountOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)

		let vmLocation = try StorageLocation(runMode: self.common.runMode).find(self.mount.name)
		let config: CakeConfig = try vmLocation.config()
		let directorySharingAttachments = config.mounts

		try self.mount.mounts.forEach { attachment in
			let description = attachment.description

			if directorySharingAttachments.contains(where: { $0.description == description }) {
				throw ValidationError("Mount \(description) already exists")
			}
		}
	}

	func run() throws {
		let vmLocation = try StorageLocation(runMode: self.common.runMode).find(self.mount.name)
		let response = try CakedLib.MountHandler.Mount(vmLocation: vmLocation, mounts: self.mount.mounts)

		Logger.appendNewLine(self.common.format.render(response))

		if case let .error(error) = response.response {
			FileHandle.standardError.write("\(error)\n".data(using: .utf8)!)
			throw CakedLib.ExitCode(EXIT_FAILURE)
		}
	}
}
