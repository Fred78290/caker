import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct LaunchHandler: CakedCommandAsync {
	var options: BuildOptions
	var waitIPTimeout = 180

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		return on.makeFutureWithTask {
			let message = try await CakedLib.LaunchHandler.buildAndLaunchVM(runMode: runMode, options: options, waitIPTimeout: waitIPTimeout, startMode: .service)

			return Caked_Reply.with { reply in
				reply.vms = Caked_VirtualMachineReply.with {
					$0.message = message
				}
			}
		}
	}

}
