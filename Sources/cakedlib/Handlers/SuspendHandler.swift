import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import Shout
import SystemConfiguration
import CakeAgentLib

public struct SuspendHandler {
	public static func suspendVM(name: String, runMode: Utils.RunMode) throws -> SuspendedObject {
		let location = try StorageLocation(runMode: runMode).find(name)

		if location.status == .running {
			try location.suspendVirtualMachine(runMode: runMode)
			return SuspendedObject(name: name, suspended: true, reason: "VM Suspended")
		}

		return SuspendedObject(name: name, suspended: false, reason: "VM is not running")
	}

	public static func suspendVMs(names: [String], runMode: Utils.RunMode) -> SuspendReply {
		do {
			return SuspendReply(
				objects: try names.compactMap {
					try SuspendHandler.suspendVM(name: $0, runMode: runMode)
				}, success: true, reason: "Success")
		} catch {
			return SuspendReply(objects: [], success: false, reason: "\(error)")
		}
	}
}
