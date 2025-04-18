import Foundation
import NIO
import GRPC
import GRPCLib
import CakeAgentLib

struct RunHandler: CakedCommandAsync {
	var request: Caked_RunCommand
	var client: CakeAgentConnection

	static func run(name: String, command: String, arguments: [String], input: Data?, client: CakeAgentConnection, callOptions: CallOptions?, asSystem: Bool) async throws -> Caked_RunReply {
		var vmname = name

		if vmname == "" {
			vmname = "primary"

			if StorageLocation(asSystem: asSystem).exists(vmname) == false {
				Logger(self).info("Creating primary VM")
				try await BuildHandler.build(name: vmname, options: .init(name: vmname), asSystem: asSystem)
			}
		}

		let vmLocation: VMLocation = try StorageLocation(asSystem: asSystem).find(vmname)

		if vmLocation.status != .running {
			Logger(self).info("Starting \(vmname)")

			_ = try StartHandler(location: vmLocation, waitIPTimeout: 180, startMode: .background).run(on: Root.group.next(), asSystem: asSystem)
		}
		return try client.run(command: command, arguments: arguments, input: input)
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<Caked_Reply> {
		on.makeFutureWithTask{
			let reply = try await Self.run(name: self.request.vmname, command: self.request.command, arguments: self.request.args, input: self.request.hasInput ? self.request.input : nil, client: self.client, callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))), asSystem: asSystem)

			return Caked_Reply.with {
				$0.run = reply
			}
		}
	}
}
