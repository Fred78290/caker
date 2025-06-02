import ArgumentParser
import CakeAgentLib
import Foundation
@preconcurrency import GRPC
import GRPCLib
import Logging
import NIO
import TextTable

struct Umount: ParsableCommand {
	static let configuration = UmountOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Umount options")
	var umount: UmountOptions

	public func validate() throws {
		Logger.setLevel(self.common.logLevel)

		let vmLocation = try StorageLocation(runMode: self.common.runMode).find(self.umount.name)
		let config = try vmLocation.config()
		let directorySharingAttachments = config.mounts

		try self.umount.mounts.forEach { attachment in
			let description = attachment.description

			if directorySharingAttachments.contains(where: { $0.description == description }) == false {
				throw ValidationError("Mount \(description) does not exist")
			}
		}
	}

	func run() throws {
		let vmLocation = try StorageLocation(runMode: self.common.runMode).find(self.umount.name)
		let response = try MountHandler.Umount(vmLocation: vmLocation, mounts: self.umount.mounts)

		Logger.appendNewLine(self.common.format.render(response))

		if case let .error(error) = response.response {
			FileHandle.standardError.write("\(error)\n".data(using: .utf8)!)
			throw ExitCode(EXIT_FAILURE)
		}
	}

}
