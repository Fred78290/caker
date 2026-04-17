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
	let startMode: CakedLib.StartHandler.StartMode
	let gcd: Bool
	let force: Bool
	let waitIPTimeout: Int
	let names: [String]
	
	init(request: Caked_RestartRequest, startMode: CakedLib.StartHandler.StartMode, gcd: Bool) {
		self.startMode = startMode
		self.gcd = gcd
		self.names = request.names
		self.force = request.force
		self.waitIPTimeout = Int(request.waitIptimeout)
	}

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms.restarted = .with {
				$0.objects = []
				$0.success = false
				$0.reason = error.reason
			}
		}
	}

	mutating func run(on: any EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms.restarted = CakedLib.RestartHandler.restart(names: self.names, startMode: startMode, gcd: gcd, force: self.force, waitIPTimeout: self.waitIPTimeout, runMode: runMode).caked
		}
	}
	
}
