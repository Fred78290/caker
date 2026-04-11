import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import Shout
import SystemConfiguration
import CakeAgentLib

public struct SuspendHandler {
	public static func suspendVM(vmURL: URL, runMode: Utils.RunMode) throws -> SuspendedObject {
		try suspendVM(location: VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode), runMode: runMode)
	}

	public static func suspendVM(name: String, runMode: Utils.RunMode) throws -> SuspendedObject {
		try suspendVM(location: StorageLocation(runMode: runMode).find(name), runMode: runMode)
	}

	public static func suspendVM(location: VMLocation, runMode: Utils.RunMode) throws -> SuspendedObject {
		if location.status == .running {
			try location.suspendVirtualMachine(runMode: runMode)
			return SuspendedObject(name: location.name, suspended: true, reason: "VM Suspended")
		}

		return SuspendedObject(name: location.name, suspended: false, reason: "VM is not running")
	}

	public static func suspendVMs(names: [String], runMode: Utils.RunMode) -> SuspendReply {
		do {
			return SuspendReply(
				objects: try names.compactMap {
					try SuspendHandler.suspendVM(name: $0, runMode: runMode)
				}, success: true, reason: "Success")
		} catch {
			return SuspendReply(objects: [], success: false, reason: error.reason)
		}
	}
}
