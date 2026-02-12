//
//  RestartHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/02/2026.
//

import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct RestartHandler: CakedCommand {
	var request: Caked_RestartRequest

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms.restarted = .with {
				$0.objects = []
				$0.success = false
				$0.reason = "\(error)"
			}
		}
	}

	mutating func run(on: any EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms.restarted = CakedLib.RestartHandler.restart(names: self.request.names, force: self.request.force, waitIPTimeout: Int(self.request.waitIptimeout), runMode: runMode).caked
		}
	}
	
}
