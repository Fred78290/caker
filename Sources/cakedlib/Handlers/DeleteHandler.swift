//
//  DeleteHandler..swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/02/2025.
//
import Foundation
import GRPCLib
import NIO

public struct DeleteHandler {
	static func tryDeleteLocal(name: String, runMode: Utils.RunMode) -> DeleteReply? {
		let doIt: (VMLocation) -> DeleteReply = { location in
			if location.status != .running {
				try? FileManager.default.removeItem(at: location.rootURL)
				return DeleteReply(source: "vm", name: location.name, deleted: true, reason: "")
			} else {
				return DeleteReply(source: "vm", name: location.name, deleted: false, reason: "VM is running")
			}
		}

		if let location = try? StorageLocation(runMode: runMode).find(name) {
			return doIt(location)
		} else if let u = URL(string: name), u.scheme == "vm", let location = try? StorageLocation(runMode: runMode).find(u.host()!) {
			return doIt(location)
		}

		return nil
	}

	public static func delete(names: [String], runMode: Utils.RunMode) throws -> [DeleteReply] {
		return try names.compactMap { name in
			guard let result = tryDeleteLocal(name: name, runMode: runMode) else {
				if let u = URL(string: name) {
					var purgeableStorages: [String: CommonCacheImageCache] = [
						CloudImageCache.scheme: try CloudImageCache(runMode: runMode),
						RawImageCache.scheme: try RawImageCache(runMode: runMode),
						SimpleStreamsImageCache.scheme: try SimpleStreamsImageCache(runMode: runMode),
					]

					if true {
						let remoteDb = try Home(runMode: runMode).remoteDatabase()

						try remoteDb.keys.forEach {
							purgeableStorages[$0] = try SimpleStreamsImageCache(runMode: runMode)
						}
					}

					if let scheme = u.scheme, let cache = purgeableStorages[scheme] {
						let purgeables = try cache.purgeables()

						if let purgeable = purgeables.first(where: { cache.fqn($0).contains(u.absoluteString) }) {
							try purgeable.delete()
							return DeleteReply(source: cache.location, name: purgeable.name(), deleted: true, reason: "")
						}
						return DeleteReply(source: cache.location, name: u.lastPathComponent, deleted: false, reason: "Object not found")
					} else if let scheme = u.scheme {
						return DeleteReply(source: scheme, name: name, deleted: false, reason: "Unsupported URL scheme")
					} else {
						return DeleteReply(source: "vm", name: name, deleted: false, reason: "VM not found")
					}
				}

				return DeleteReply(source: "unknown", name: name, deleted: false, reason: "Unsupported URL")
			}

			return result
		}
	}

	public static func delete(all: Bool, names: [String], runMode: Utils.RunMode) throws -> [DeleteReply] {
		var names = names

		if all {
			names = try StorageLocation(runMode: runMode).list().map { $0.key }
		}

		return try DeleteHandler.delete(names: names, runMode: runMode)
	}
}
