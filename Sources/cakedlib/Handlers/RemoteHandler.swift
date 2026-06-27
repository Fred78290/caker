import Foundation
import GRPCLib
import NIOCore
import CakeAgentLib

public struct RemoteHandler {
	public static func addRemote(name: String, url: URL, runMode: Utils.RunMode) -> CreateRemoteReply {

		guard url.scheme == "https" || url.scheme == "http" else {
			return CreateRemoteReply(name: name, created: false, reason: String(localized: "remote unsupported url \(url.hiddenPasswordURL.absoluteString)"))
		}

		do {
			let remoteDb = try Home(runMode: runMode).remoteDatabase()

			guard remoteDb.get(name) == nil else {
				return CreateRemoteReply(name: name, created: false, reason: String(localized: "remote \(name) already exists"))
			}

			try remoteDb.upsert(name, url.absoluteString)

			return CreateRemoteReply(name: name, created: true, reason: String(localized: "remote \(name) added"))
		} catch {
			return CreateRemoteReply(name: name, created: false, reason: error.reason)
		}
	}

	public static func deleteRemote(name: String, runMode: Utils.RunMode) -> DeleteRemoteReply {
		do {
			let remoteDb = try Home(runMode: runMode).remoteDatabase()

			guard remoteDb.get(name) != nil else {
				return DeleteRemoteReply(name: name, deleted: false, reason: String(localized: "remote \(name) doesn't exists"))
			}

			try remoteDb.remove(name)

			return DeleteRemoteReply(name: name, deleted: true, reason: String(localized: "remote \(name) deleted"))
		} catch {
			return DeleteRemoteReply(name: name, deleted: false, reason: error.reason)
		}
	}

	public static func listRemote(runMode: Utils.RunMode) -> ListRemoteReply {
		do {
			let remoteDb = try Home(runMode: runMode).remoteDatabase()

			return ListRemoteReply(
				remotes: try remoteDb.map { (key: String, value: String) in
					RemoteEntry(name: key, url: value)
				}, success: true, reason: String(localized: "Success"))
		} catch {
			return ListRemoteReply(remotes: [], success: false, reason: error.reason)
		}
	}
}
