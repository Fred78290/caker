import ArgumentParser
import Foundation
import GRPCLib

public struct RenameHandler {
	public static func rename(oldname: String, newname: String, runMode: Utils.RunMode) throws -> String {
		let storage = StorageLocation(runMode: runMode)
		let vmLocation = try storage.find(oldname)

		if vmLocation.status == .running {
			throw ValidationError("VM \(oldname) is running")
		}

		try storage.relocate(newname, from: vmLocation)

		return "VM renamed from (\(oldname)) to (\(newname))"
	}
}
