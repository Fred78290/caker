import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO

struct RunHandler: CakedCommandAsync {
	var request: Caked_RunCommand
	var client: CakeAgentConnection

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with {
			$0.run = .with {
				$0.exitCode = 1
				$0.stderr = Data("\(error)".utf8)
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		on.makeFutureWithTask {
			let reply = try await CakedLib.RunHandler.run(
				name: self.request.vmname, command: self.request.command, arguments: self.request.args, input: self.request.hasInput ? self.request.input : nil, client: self.client,
				callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))), runMode: runMode)

			return Caked_Reply.with {
				$0.run = reply
			}
		}
	}
}
