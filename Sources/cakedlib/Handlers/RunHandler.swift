import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO

public struct RunHandler {
	public static func run(name: String, command: String, arguments: [String], input: Data?, client: CakeAgentConnection, callOptions: CallOptions?, runMode: Utils.RunMode) async throws -> Caked_RunReply {
		var vmname = name

		if vmname == "" {
			vmname = "primary"

			if StorageLocation(runMode: runMode).exists(vmname) == false {
				Logger(self).info("Creating primary VM")
				try await BuildHandler.build(name: vmname, options: .init(name: vmname), runMode: runMode)
			}
		}

		let vmLocation: VMLocation = try StorageLocation(runMode: runMode).find(vmname)

		if vmLocation.status != .running {
			Logger(self).info("Starting \(vmname)")

			_ = try CakedLib.StartHandler.startVM(on: Utilities.group.next(), vmLocation: vmLocation, config: try vmLocation.config(), waitIPTimeout: 180, startMode: .background, runMode: runMode)
		}

		return try client.run(command: command, arguments: arguments, input: input)
	}

}
