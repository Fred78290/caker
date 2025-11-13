import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO

struct InfosHandler: CakedCommand {
	var request: Caked_InfoRequest
	var client: CakeAgentConnection

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
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
			let result: VirtualMachineStatusReply = CakedLib.InfosHandler.infos(name: self.request.name, runMode: runMode, client: CakeAgentHelper(on: on, client: try client.createClient()), callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))))
			return Caked_Reply.with {
				$0.vms = Caked_VirtualMachineReply.with {
					$0.status = result.caked
				}
			}
		} catch {
			return Caked_Reply.with {
				$0.vms = Caked_VirtualMachineReply.with {
					$0.status = .with {
						$0.success = false
						$0.reason = "\(error)"
					}
				}
			}
		}
	}
}
