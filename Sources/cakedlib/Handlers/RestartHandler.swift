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
			return try restart(location: StorageLocation(runMode: runMode).find(name), force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
		} catch {
			return RestartedObject(name: name, restarted: false, reason: "\(error)")
		}
	}

	public static func restart(vmURL: URL, force: Bool, waitIPTimeout: Int, runMode: Utils.RunMode) -> RestartedObject {
		do {
			return try restart(location: VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode), force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
		} catch {
			return RestartedObject(name: vmURL.absoluteString, restarted: false, reason: "\(error)")
		}
	}

	public static func restart(location: VMLocation, force: Bool, waitIPTimeout: Int, runMode: Utils.RunMode) -> RestartedObject {
		do {
			if location.status == .running {
				try location.restartVirtualMachine(force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
				return RestartedObject(name: location.name, restarted: true, reason: "")
			}
			
			return RestartedObject(name: location.name, restarted: false, reason: "VM is not running")
		} catch {
			return RestartedObject(name: location.name, restarted: false, reason: "\(error)")
		}
	}
	
	public static func restart(names: [String], force: Bool, waitIPTimeout: Int, runMode: Utils.RunMode) -> RestartReply {
		let restarted = names.map {
			RestartHandler.restart(name: $0, force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
		}
		
		return RestartReply(objects: restarted, success: true, reason: "Success")
	}
}
