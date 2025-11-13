import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct LaunchHandler: CakedCommandAsync {
	var options: BuildOptions
	var waitIPTimeout = 180

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.launched = .with {
					$0.name = self.options.name
					$0.launched = false
					$0.reason = "\(error)"
				}
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) -> EventLoopFuture<Caked_Reply> {
		return on.makeFutureWithTask {
			let result = await CakedLib.LaunchHandler.buildAndLaunchVM(runMode: runMode, options: options, waitIPTimeout: waitIPTimeout, startMode: .service)

			return Caked_Reply.with { reply in
				reply.vms = Caked_VirtualMachineReply.with {
					$0.launched = result.caked
				}
			}
		}
	}

}
