//
//  InstallAgentHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 15/02/2026.
//

import Foundation
import GRPCLib
import CakeAgentLib

public struct InstallAgentHandler {
	public static func installAgent(name: String, timeout: UInt, runMode: Utils.RunMode) -> InstalledAgentReply {
		do {
			let location = try StorageLocation(runMode: runMode).find(name)
			
			guard location.status == .running else {
				return InstalledAgentReply(name: name, installed: false, reason: "VM is not running")
			}

			let result = try createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: runMode).installAgent(timeout: timeout)

			return InstalledAgentReply(name: name, installed: result.installed , reason: result.reason)
		} catch {
			return InstalledAgentReply(name: name, installed: false , reason: "\(error)")
		}
	}
}
