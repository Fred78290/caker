import CakedLib
import Dispatch
import Foundation
import GRPCLib
import NIOCore

struct ConfigureHandler: CakedCommandAsync, Sendable {
	var options: ConfigureOptions

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.configured = .with {
					$0.configured = false
					$0.reason = "\(error)"
				}
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		return on.submit {
			return Caked_Reply.with { reply in
				reply.vms = Caked_VirtualMachineReply.with {
					$0.configured = CakedLib.ConfigureHandler.configure(name: self.options.name, options: options, runMode: runMode).caked
				}
			}
		}
	}
}
