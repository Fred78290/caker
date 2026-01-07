import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import Shout
import SystemConfiguration
import CakeAgentLib

public struct StopHandler {
	public static func restart(name: String, force: Bool, runMode: Utils.RunMode) throws -> StoppedObject {
		let location = try StorageLocation(runMode: runMode).find(name)

		if location.status == .running {
			try location.restartVirtualMachine(force: force, runMode: runMode)
			return StoppedObject(name: name, stopped: true, reason: "")
		}

		return StoppedObject(name: name, stopped: false, reason: "VM is not running")
	}

	public static func stopVM(name: String, force: Bool, runMode: Utils.RunMode) throws -> StoppedObject {
		let location = try StorageLocation(runMode: runMode).find(name)

		if location.status == .running {
			try location.stopVirtualMachine(force: force, runMode: runMode)
			return StoppedObject(name: name, stopped: true, reason: "")
		}

		return StoppedObject(name: name, stopped: false, reason: "VM is not running")
	}

	public static func stopVMs(all: Bool, names: [String], force: Bool, runMode: Utils.RunMode) -> StopReply {
		do {
			let stopped: [StoppedObject]

			if all {
				stopped = try StorageLocation(runMode: runMode).list().compactMap { (key: String, value: VMLocation) in
					if value.status == .running {
						try value.stopVirtualMachine(force: force, runMode: runMode)

						return StoppedObject(name: key, stopped: true, reason: "")
					}

					return nil
				}
			} else {
				stopped = try names.map {
					try StopHandler.stopVM(name: $0, force: force, runMode: runMode)
				}
			}

			return StopReply(objects: stopped, success: true, reason: "Success")
		} catch {
			return StopReply(objects: [], success: false, reason: "\(error)")
		}
	}
}
