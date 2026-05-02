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
	public static func restart(name: String, startMode: StartHandler.StartMode, gcd: Bool, force: Bool, waitIPTimeout: Int, runMode: Utils.RunMode) -> RestartedObject {
		do {
			return try restart(location: StorageLocation(runMode: runMode).find(name), startMode: startMode, gcd: gcd, force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
		} catch {
			return RestartedObject(name: name, restarted: false, reason: error.reason)
		}
	}

	public static func restart(vmURL: URL, startMode: StartHandler.StartMode, gcd: Bool, force: Bool, waitIPTimeout: Int, runMode: Utils.RunMode) -> RestartedObject {
		do {
			return try restart(location: VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode), startMode: startMode, gcd: gcd, force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
		} catch {
			return RestartedObject(name: vmURL.absoluteString, restarted: false, reason: error.reason)
		}
	}

	public static func restart(location: VMLocation, startMode: StartHandler.StartMode, gcd: Bool, force: Bool, waitIPTimeout: Int, runMode: Utils.RunMode) -> RestartedObject {
		do {
			if case .running = location.status {
				try location.restartVirtualMachine(startMode: startMode, gcd: gcd, force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
				return RestartedObject(name: location.name, restarted: true, reason: String.empty)
			}
			
			return RestartedObject(name: location.name, restarted: false, reason: String(localized: "VM is not running"))
		} catch {
			return RestartedObject(name: location.name, restarted: false, reason: error.reason)
		}
	}
	
	public static func restart(names: [String], startMode: StartHandler.StartMode, gcd: Bool, force: Bool, waitIPTimeout: Int, runMode: Utils.RunMode) -> RestartReply {
		let restarted = names.map {
			RestartHandler.restart(name: $0, startMode: startMode, gcd: gcd, force: force, waitIPTimeout: waitIPTimeout, runMode: runMode)
		}
		
		return RestartReply(objects: restarted, success: true, reason: String(localized: "Success"))
	}
}
