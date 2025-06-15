import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import SystemConfiguration
import CakedLib


struct ListHandler: CakedCommand {
	let vmonly: Bool

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		let result = try CakedLib.ListHandler.list(vmonly: self.vmonly, runMode: runMode)

		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.list = Caked_VirtualMachineInfoReply.with {
					$0.infos = result.map {
						$0.toCaked_VirtualMachineInfo()
					}
				}
			}
		}
	}
}
