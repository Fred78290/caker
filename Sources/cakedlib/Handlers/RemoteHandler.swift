import Foundation
import GRPCLib
import NIOCore

public struct RemoteHandler {
	public static func addRemote(name: String, url: URL, runMode: Utils.RunMode) throws -> String {
		let remoteDb = try Home(runMode: runMode).remoteDatabase()

		if url.scheme == "https" || url.scheme == "http" {
			guard remoteDb.get(name) != nil else {
				remoteDb.add(name, url.absoluteString)
				try remoteDb.save()

				return "remote \(name) added"
			}

			throw ServiceError("remote \(name) already exists")
		} else if let scheme = url.scheme {
			throw ServiceError("remote unsupported scheme: \(scheme) for \(url)")
		}

		throw ServiceError("remote unsupported url: \(url)")
	}

	public static func deleteRemote(name: String, runMode: Utils.RunMode) throws -> String {
		let remoteDb = try Home(runMode: runMode).remoteDatabase()

		if remoteDb.get(name) != nil {
			remoteDb.remove(name)
			try remoteDb.save()

			return "remote \(name) deleted"
		}

		throw ServiceError("remote \(name) doesn't exists")
	}

	public static func listRemote(runMode: Utils.RunMode) throws -> [RemoteEntry] {
		let remoteDb = try Home(runMode: runMode).remoteDatabase()

		return try remoteDb.map { (key: String, value: String) in
			RemoteEntry(name: key, url: value)
		}
	}
}
