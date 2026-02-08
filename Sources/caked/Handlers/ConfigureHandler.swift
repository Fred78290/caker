import CakedLib
import Dispatch
import Foundation
import GRPCLib
import NIOCore

struct ConfigureHandler: CakedCommand, Sendable {
	var options: ConfigureOptions

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.configured = .with {
					$0.configured = false
					$0.reason = "\(error)"
				}
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.configured = CakedLib.ConfigureHandler.configure(name: self.options.name, options: options, runMode: runMode).caked
			}
		}
	}
}
