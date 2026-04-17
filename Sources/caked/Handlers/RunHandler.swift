import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO

struct RunHandler: CakedCommandAsync {
	var request: Caked_RunCommand
	var provider: CakedProvider

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.run = .with {
				$0.exitCode = 1
				$0.stderr = Data(error.reason.utf8)
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) async -> Caked_Reply {
		do {
			let reply = try await CakedLib.RunHandler.run(name: self.request.vmname,
														  command: self.request.command,
														  arguments: self.request.args,
														  input: self.request.hasInput ? self.request.input : nil,
														  client: try self.provider.createCakeAgentConnection(vmName: self.request.vmname),
														  callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))),
														  runMode: runMode)

			return Caked_Reply.with {
				$0.run = reply
			}
		} catch {
			return replyError(error: error)
		}
	}
}
