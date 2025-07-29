import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import Shout
import SystemConfiguration

public struct StopHandler {
	public static func restart(name: String, force: Bool, runMode: Utils.RunMode) throws -> StopReply {
		let location = try StorageLocation(runMode: runMode).find(name)

		if location.status == .running {
			try location.restartVirtualMachine(force: force, runMode: runMode)
			return StopReply(name: name, status: "VM \(name) stopped", stopped: true, reason: "")
		}

		return StopReply(name: name, status: "VM \(name) is not running", stopped: false, reason: "VM is not running")
	}

	public static func stopVM(name: String, force: Bool, runMode: Utils.RunMode) throws -> StopReply {
		let location = try StorageLocation(runMode: runMode).find(name)

		if location.status == .running {
			try location.stopVirtualMachine(force: force, runMode: runMode)
			return StopReply(name: name, status: "VM \(name) stopped", stopped: true, reason: "")
		}

		return StopReply(name: name, status: "VM \(name) is not running", stopped: false, reason: "VM is not running")
	}

	public static func stopVMs(all: Bool, names: [String], force: Bool, runMode: Utils.RunMode) throws -> [StopReply] {
		if all {
			return try StorageLocation(runMode: runMode).list().compactMap { (key: String, value: VMLocation) in
				if value.status == .running {
					try value.stopVirtualMachine(force: force, runMode: runMode)

					return StopReply(name: key, status: "VM \(key) stopped", stopped: true, reason: "")
				}

				return nil
			}
		} else {
			return try names.compactMap {
				try StopHandler.stopVM(name: $0, force: force, runMode: runMode)
			}
		}
	}
}
