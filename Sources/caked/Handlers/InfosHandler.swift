import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO

struct InfosHandler: CakedCommand {
	var request: Caked_InfoRequest
	var client: CakeAgentConnection

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		return try Caked_Reply.with { reply in
			reply.vms = try Caked_VirtualMachineReply.with {
				$0.infos = try CakedLib.InfosHandler.infos(name: self.request.name, runMode: runMode, client: CakeAgentHelper(on: on, client: client.createClient()), callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))))
					.toCaked_InfoReply()
			}
		}
	}
}
