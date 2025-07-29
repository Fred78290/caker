import Dispatch
import Foundation
import GRPCLib
import NIOCore
import CakedLib

struct BuildHandler: CakedCommandAsync {
	var options: BuildOptions

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		return on.makeFutureWithTask {
			try await CakedLib.BuildHandler.build(name: self.options.name, options: self.options, runMode: runMode, progressHandler: CakedLib.BuildHandler.progressHandler)

			return Caked_Reply.with { reply in
				reply.vms = Caked_VirtualMachineReply.with {
					$0.message = "VM \(self.options.name) created"
				}
			}
		}
	}
}
