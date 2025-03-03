import ArgumentParser
import Foundation
@preconcurrency import GRPC
import GRPCLib
import CakeAgentLib
import Logging
import NIO
import TextTable

struct Mount: CakeAgentAsyncParsableCommand {
	static var configuration = CommandConfiguration(commandName: "mount", abstract: "Mount directory share into VM")

	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logging.Logger.Level = .info

	@Argument(help: "VM name")
	var name: String = ""

	@Option(name: .shortAndLong, help: "Output format")
	var format: Format = .text

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Additional directory shares\n", discussion: mount_help))
	var shares: [String] = []

	@OptionGroup(title: "override client agent options", visibility: .hidden)
	var options: CakeAgentClientOptions

	var createVM: Bool = false

	var mounts: [DirectorySharingAttachment] = []

	mutating public func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}

		self.mounts = try self.shares.compactMap { try DirectorySharingAttachment(parseFrom: $0) }
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async throws {
		let vmLocation = try StorageLocation(asSystem: runAsSystem).find(self.name)
		let response = try MountHandler.Mount(vmLocation: vmLocation, mounts: self.mounts, client: client)

		print(format.renderList(style: Style.grid, uppercased: true, response.mounts.map { MountHandler.MountVirtioFSReply($0) }))
	}

}
