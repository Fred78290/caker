import ArgumentParser
import Foundation
@preconcurrency import GRPC
import GRPCLib
import CakeAgentLib
import Logging
import NIO
import TextTable

struct Umount: CakeAgentAsyncParsableCommand {
	static var configuration = CommandConfiguration(commandName: "umount", abstract: "Unmount a directory share from a VM")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Argument(help: "VM name")
	var name: String = ""

	@Option(name: .shortAndLong, help: "Output format")
	var format: Format = .text

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Give host path to umount", discussion: "Remove directory shares. If omitted all mounts will be removed from the named vm" ))
	var shares: [String] = []

	@OptionGroup(title: "override client agent options", visibility: .hidden)
	var options: CakeAgentClientOptions

	var createVM: Bool = false

	var mounts: [DirectorySharingAttachment] = []

	mutating public func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		if self.shares.isEmpty {
			let vmLocation = try StorageLocation(asSystem: runAsSystem).find(self.name)
			let config = try vmLocation.config()
			self.mounts = config.mounts
		} else {
			self.mounts = try self.shares.compactMap { try DirectorySharingAttachment(parseFrom: $0) }
		}
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		let vmLocation = try StorageLocation(asSystem: runAsSystem).find(self.name)
		let response = try MountHandler.Umount(vmLocation: vmLocation, mounts: self.mounts, client: client)

		print(format.renderList(style: Style.grid, uppercased: true, response.mounts.map { MountHandler.MountVirtioFSReply($0) }))
	}

}
