import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO
import NIOPortForwarding

struct InfosHandler: CakedCommand {
	var request: Caked_InfoRequest
	var provider: CakedProvider

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.status = .with {
					$0.success = false
					$0.reason = error.reason
				}
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		do {
			let result = try CakedLib.InfosHandler.infos(name: self.request.name,
														 runMode: runMode,
														 client: try provider.createCakeAgentHelper(vmName: self.request.name),
														 callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))))
			let reply = VirtualMachineStatusReply(infos: result.infos, success: true, reason: "Success")

			return Caked_Reply.with {
				$0.vms = Caked_VirtualMachineReply.with {
					if request.includeConfig {
						$0.status = reply.caked(config: result.config)
					} else {
						$0.status = reply.caked

					}
				}
			}
		} catch {
			return replyError(error: error)
		}
	}
}

