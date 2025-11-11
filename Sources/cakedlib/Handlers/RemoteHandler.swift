import Foundation
import GRPCLib
import NIOCore

public struct RemoteHandler {
	public static func addRemote(name: String, url: URL, runMode: Utils.RunMode) -> CreateRemoteReply {

		guard url.scheme == "https" || url.scheme == "http" else {
			return CreateRemoteReply(name: name, created: false, reason: "remote unsupported url \(url)")
		}

		do {
			let remoteDb = try Home(runMode: runMode).remoteDatabase()
			
			guard remoteDb.get(name) == nil else {
				return CreateRemoteReply(name: name, created: false, reason: "remote \(name) already exists")
			}
			
			remoteDb.add(name, url.absoluteString)
			try remoteDb.save()
			
			return CreateRemoteReply(name: name, created: true, reason: "remote \(name) added")
		} catch {
			return CreateRemoteReply(name: name, created: false, reason: "\(error)")
		}
	}

	public static func deleteRemote(name: String, runMode: Utils.RunMode) -> DeleteRemoteReply {
		do {
			let remoteDb = try Home(runMode: runMode).remoteDatabase()

			guard remoteDb.get(name) != nil else {
				return DeleteRemoteReply(name: name, deleted: false, reason: "remote \(name) doesn't exists")
			}

			remoteDb.remove(name)
			try remoteDb.save()

			return DeleteRemoteReply(name: name, deleted: true, reason: "remote \(name) deleted")
		} catch {
			return DeleteRemoteReply(name: name, deleted: false, reason: "\(error)")
		}
	}

	public static func listRemote(runMode: Utils.RunMode) throws -> [RemoteEntry] {
		let remoteDb = try Home(runMode: runMode).remoteDatabase()

		return try remoteDb.map { (key: String, value: String) in
			RemoteEntry(name: key, url: value)
		}
	}
}
