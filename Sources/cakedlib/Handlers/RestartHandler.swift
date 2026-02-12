//
//  RestartHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/02/2026.
//

import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import Shout
import SystemConfiguration
import CakeAgentLib

public struct RestartHandler {
	public static func restart(name: String, force: Bool, waitIPTimeout: Int, runMode: Utils.RunMode) -> RestartedObject {
		do {
			let location = try StorageLocation(runMode: runMode).find(name)
			
			if location.status == .running {
				try location.restartVirtualMachine(force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
				return RestartedObject(name: name, restarted: true, reason: "")
			}
			
			return RestartedObject(name: name, restarted: false, reason: "VM is not running")
		} catch {
			return RestartedObject(name: name, restarted: false, reason: "\(error)")
		}
	}
	
	public static func restart(names: [String], force: Bool, waitIPTimeout: Int, runMode: Utils.RunMode) -> RestartReply {
		let restarted = names.map {
			RestartHandler.restart(name: $0, force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
		}
		
		return RestartReply(objects: restarted, success: true, reason: "Success")
	}
}
