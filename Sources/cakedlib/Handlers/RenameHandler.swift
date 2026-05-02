import ArgumentParser
import Foundation
import GRPCLib
import CakeAgentLib

public struct RenameHandler {
	public static func rename(oldname: String, newname: String, runMode: Utils.RunMode) -> RenameReply {
		do {
			let storage = StorageLocation(runMode: runMode)
			let location = try storage.find(oldname)

			if case .running = location.status {
				return RenameReply(oldName: oldname, newName: newname, renamed: false, reason: String(localized: "VM is running"))
			}

			try storage.relocate(newname, from: location)

			return RenameReply(oldName: oldname, newName: newname, renamed: true, reason: String(localized: "VM renamed"))
		} catch {
			return RenameReply(oldName: oldname, newName: newname, renamed: false, reason: error.reason)
		}
	}
}
