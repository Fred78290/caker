import Dispatch
import Foundation
import GRPCLib
import NIOCore
import CakedLib


struct ConfigureHandler: CakedCommandAsync, Sendable {
	var options: ConfigureOptions

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		return on.submit {
			return try Caked_Reply.with { reply in
				reply.vms = try Caked_VirtualMachineReply.with {
					$0.message = try CakedLib.ConfigureHandler.configure(name: self.options.name, options: options, runMode: runMode)
				}
			}
		}
	}
}
