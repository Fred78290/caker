import CakedLib
import Dispatch
import Foundation
import GRPCLib
import NIOCore

struct BuildHandler: CakedCommandAsync {
	var options: BuildOptions

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		return on.makeFutureWithTask {
			let result = await CakedLib.BuildHandler.build(name: self.options.name, options: self.options, runMode: runMode, progressHandler: ProgressObserver.progressHandler)

			return Caked_Reply.with { reply in
				reply.vms = Caked_VirtualMachineReply.with {
					$0.builded = result.caked
				}
			}
		}
	}
}
