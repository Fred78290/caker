import CakedLib
import Dispatch
import Foundation
import GRPCLib
import NIOCore

struct BuildHandler: CakedCommandAsync {
	var options: BuildOptions

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.builded = .with {
					$0.builded = false
					$0.reason = "\(error)"
				}
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> EventLoopFuture<Caked_Reply> {
		return on.makeFutureWithTask {
			let result = await CakedLib.BuildHandler.build(options: self.options, runMode: runMode, progressHandler: ProgressObserver.progressHandler)

			return Caked_Reply.with {
				$0.vms = Caked_VirtualMachineReply.with {
					$0.builded = result.caked
				}
			}
		}
	}
}
