import ArgumentParser
import Foundation
import GRPCLib
import NIOCore

struct RenameHandler: CakedCommand {
	let request: Caked_RenameRequest

	static func rename(oldname: String, newname: String) throws {
		let storage = StorageLocation(asSystem: runAsSystem)
		let vmLocation = try storage.find(oldname)

		if vmLocation.status == .running {
			throw ValidationError("VM \(oldname) is running")
		}

		try storage.relocate(newname, from: vmLocation)
	}

	mutating func run(on: any EventLoop, asSystem: Bool) throws -> String {
		let oldname = self.request.oldname
		let newname = self.request.newname

		try Self.rename(oldname: oldname, newname: newname)

		return "VM renamed from (\(oldname)) to (\(newname))"
	}
}