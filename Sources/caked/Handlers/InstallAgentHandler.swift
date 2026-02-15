//
//  InstallAgentHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 15/02/2026.
//
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO

struct InstallAgentHandler: CakedCommand {
	var request: Caked_InstallAgentRequest

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.installedAgent = Caked_InstalledAgentReply.with {
					$0.installed = false
					$0.reason = "\(error)"
				}
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		let result = CakedLib.InstallAgentHandler.installAgent(
			name: self.request.name, timeout: UInt(self.request.timeout), runMode: runMode)

		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.installedAgent = result.caked
			}
		}
	}
}
