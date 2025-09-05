import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import Shout
import SystemConfiguration

public struct SuspendHandler {
	public static func suspendVM(name: String, runMode: Utils.RunMode) throws -> SuspendReply {
		let location = try StorageLocation(runMode: runMode).find(name)

		if location.status == .running {
			try location.suspendVirtualMachine(runMode: runMode)
			return SuspendReply(name: name, status: "VM \(name) suspended", suspended: true, reason: "")
		}

		return SuspendReply(name: name, status: "VM \(name) is not running", suspended: false, reason: "VM is not running")
	}

	public static func suspendVMs(names: [String], runMode: Utils.RunMode) throws -> [SuspendReply] {
		return try names.compactMap {
			try SuspendHandler.suspendVM(name: $0, runMode: runMode)
		}
	}
}
