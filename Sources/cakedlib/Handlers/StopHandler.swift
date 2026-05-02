import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import Shout
import SystemConfiguration
import CakeAgentLib

public struct StopHandler {
	public static func stopVM(vmURL: URL, force: Bool, runMode: Utils.RunMode) -> StoppedObject {
		do {
			return try stopVM(location: VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode), force: force, runMode: runMode)
		} catch {
			return StoppedObject(name: vmURL.absoluteString, stopped: false, reason: error.reason)
		}
	}

	public static func stopVM(name: String, force: Bool, runMode: Utils.RunMode) -> StoppedObject {
		do {
			return try stopVM(location: StorageLocation(runMode: runMode).find(name), force: force, runMode: runMode)
		} catch {
			return StoppedObject(name: name, stopped: false, reason: error.reason)
		}
	}

	public static func stopVM(location: VMLocation, force: Bool, runMode: Utils.RunMode) -> StoppedObject {
		do {
			if case .running(let mode) = location.status {
				guard mode.isAllowed else {
					throw ServiceError(String(localized: "VM \(location.name) is running in Caker application and use it to do action"))
				}

				try location.stopVirtualMachine(force: force, runMode: runMode)

				return StoppedObject(name: location.name, stopped: true, reason: String.empty)
			}
			
			return StoppedObject(name: location.name, stopped: false, reason: String(localized: "VM is not running"))
		} catch {
			return StoppedObject(name: location.name, stopped: false, reason: error.reason)
		}
	}

	public static func stopVMs(all: Bool, names: [String], force: Bool, runMode: Utils.RunMode) -> StopReply {
		do {
			let stopped: [StoppedObject]

			if all {
				stopped = try StorageLocation(runMode: runMode).list().keys.map {
					return StopHandler.stopVM(name: $0, force: force, runMode: runMode)
				}
			} else {
				stopped = names.uniqued().map {
					return StopHandler.stopVM(name: $0, force: force, runMode: runMode)
				}
			}

			return StopReply(objects: stopped, success: true, reason: String(localized: "Success"))
		} catch {
			return StopReply(objects: [], success: false, reason: error.reason)
		}
	}
}
