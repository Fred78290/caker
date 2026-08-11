import ArgumentParser
import Foundation
import GRPCLib
import CakeAgentLib

public struct RenameHandler {
	public static func rename(location: VMLocation, newname: String, runMode: Utils.RunMode) -> RenameReply {
		let oldname = location.name

		do {
			switch location.status {
			case .running:
				return RenameReply(oldName: oldname, newName: newname, renamed: false, reason: String(localized: "VM is running"))
			case .paused:
				return RenameReply(oldName: oldname, newName: newname, renamed: false, reason: String(localized: "VM is paused"))
			case .stopped:
				break
			}

			guard oldname != newname else {
				return RenameReply(oldName: oldname, newName: newname, renamed: true, reason: String(localized: "VM renamed"))
			}

			let storage = StorageLocation(runMode: runMode)

			guard storage.exists(newname) == false else {
				return RenameReply(oldName: oldname, newName: newname, renamed: false, reason: String(localized: "Target vm already exists"))
			}

			try storage.relocate(newname, from: location)

			return RenameReply(oldName: oldname, newName: newname, renamed: true, reason: String(localized: "VM renamed"))
		} catch {
			return RenameReply(oldName: oldname, newName: newname, renamed: false, reason: error.reason)
		}
	}

	public static func rename(oldname: String, newname: String, runMode: Utils.RunMode) -> RenameReply {
		do {
			let location = try StorageLocation(runMode: runMode).find(oldname)

			return rename(location: location, newname: newname, runMode: runMode)
		} catch {
			return RenameReply(oldName: oldname, newName: newname, renamed: false, reason: error.reason)
		}
	}

	public static func rename(vmURL: URL, newname: String, runMode: Utils.RunMode) -> RenameReply {
		do {
			let location = try VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode)

			return rename(location: location, newname: newname, runMode: runMode)
		} catch {
			return RenameReply(oldName: vmURL.absoluteString, newName: newname, renamed: false, reason: error.reason)
		}
	}
}
