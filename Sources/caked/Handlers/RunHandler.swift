import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO

struct RunHandler: CakedCommandAsync {
	var request: Caked_RunCommand
	var client: CakeAgentConnection

	static func run(name: String, command: String, arguments: [String], input: Data?, client: CakeAgentConnection, callOptions: CallOptions?, runMode: Utils.RunMode) async throws -> Caked_RunReply {
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

			_ = try StartHandler(location: vmLocation, waitIPTimeout: 180, startMode: .background).run(on: Root.group.next(), runMode: runMode)
		}
		return try client.run(command: command, arguments: arguments, input: input)
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		on.makeFutureWithTask {
			let reply = try await Self.run(
				name: self.request.vmname, command: self.request.command, arguments: self.request.args, input: self.request.hasInput ? self.request.input : nil, client: self.client,
				callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))), runMode: runMode)

			return Caked_Reply.with {
				$0.run = reply
			}
		}
	}
}
