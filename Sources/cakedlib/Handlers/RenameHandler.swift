import ArgumentParser
import Foundation
import GRPCLib
import CakeAgentLib

public struct RenameHandler {
	public static func rename(oldname: String, newname: String, runMode: Utils.RunMode) -> RenameReply {
		do {
			let storage = StorageLocation(runMode: runMode)
			let location = try storage.find(oldname)

			if location.status == .running {
				return RenameReply(oldName: oldname, newName: newname, renamed: false, reason: "VM is running")
			}

			try storage.relocate(newname, from: location)

			return RenameReply(oldName: oldname, newName: newname, renamed: true, reason: "VM renamed")
		} catch {
			return RenameReply(oldName: oldname, newName: newname, renamed: false, reason: "\(error)")
		}
	}
}
