import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO
import NIOPortForwarding


struct InfosHandler: CakedCommand {
	var request: Caked_InfoRequest
	var client: CakeAgentConnection

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.status = .with {
					$0.success = false
					$0.reason = "\(error)"
				}
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		do {
			let result = try CakedLib.InfosHandler.infos(
				name: self.request.name, runMode: runMode, client: CakeAgentHelper(on: on, client: try client.createClient()), callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))))
			let reply = VirtualMachineStatusReply(infos: result.infos, success: true, reason: "Success")

			return Caked_Reply.with {
				$0.vms = Caked_VirtualMachineReply.with {
					var caked = reply.caked

					if request.includeConfig {
						caked.config = result.config.caked
					}

					$0.status = caked
				}
			}
		} catch {
			return replyError(error: error)
		}
	}
}

