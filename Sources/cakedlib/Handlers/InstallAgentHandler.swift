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
	public static func installAgent(vmURL: URL, timeout: UInt, runMode: Utils.RunMode) -> InstalledAgentReply {
		do {
			return installAgent(location: try VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode), timeout: timeout, runMode: runMode)
		} catch {
			return InstalledAgentReply(name: vmURL.absoluteString, installed: false , reason: error.reason)
		}
	}

	public static func installAgent(name: String, timeout: UInt, runMode: Utils.RunMode) -> InstalledAgentReply {
		do {
			return installAgent(location: try StorageLocation(runMode: runMode).find(name), timeout: timeout, runMode: runMode)
		} catch {
			return InstalledAgentReply(name: name, installed: false , reason: error.reason)
		}
	}

	public static func installAgent(location: VMLocation, timeout: UInt, runMode: Utils.RunMode) -> InstalledAgentReply {
		do {
			guard case .running = location.status else {
				return InstalledAgentReply(name: location.name, installed: false, reason: String(localized: "VM is not running"))
			}

			let result = try createVMRunServiceClient(VMRunHandler.serviceMode, location: location, runMode: runMode).installAgent(timeout: timeout)

			return InstalledAgentReply(name: location.name, installed: result.installed , reason: result.reason)
		} catch {
			return InstalledAgentReply(name: location.name, installed: false , reason: error.reason)
		}
	}
}
