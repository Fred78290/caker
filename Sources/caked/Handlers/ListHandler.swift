import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import NIOCore
import SystemConfiguration

struct ListHandler: CakedCommand {
	let vmonly: Bool

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.list = Caked_VirtualMachineInfoReply.with {
					$0.success = false
					$0.reason = "\(error)"
				}
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		let result = try CakedLib.ListHandler.list(vmonly: self.vmonly, runMode: runMode)

		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.list = Caked_VirtualMachineInfoReply.with {
					$0.success = true
					$0.reason = "Success"
					$0.infos = result.map {
						$0.toCaked_VirtualMachineInfo()
					}
				}
			}
		}
	}
}
