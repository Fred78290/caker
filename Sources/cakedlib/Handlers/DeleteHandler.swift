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
	static func tryDeleteLocal(name: String, runMode: Utils.RunMode) -> DeletedObject? {
		func doIt(_ location: VMLocation) throws -> DeletedObject {
			if location.status != .running {
				try FileManager.default.removeItem(at: location.rootURL)
				return DeletedObject(source: "vm", name: location.name, deleted: true, reason: "VM deleted")
			} else {
				return DeletedObject(source: "vm", name: location.name, deleted: false, reason: "VM is running")
			}
		}

		do {
			if let location = try? StorageLocation(runMode: runMode).find(name) {
				return try doIt(location)
			} else if let u = URL(string: name) {
				let location: VMLocation
				
				if u.scheme == VMLocation.scheme {
					location = try StorageLocation(runMode: runMode).find(u.host(percentEncoded: false)!)
				} else {
					location = try VMLocation.newVMLocation(rootURL: u)
				}

				return try doIt(location)
			}
		} catch {
			return DeletedObject(source: "vm", name: name, deleted: false, reason: "\(error)")
		}

		return nil
	}

	public static func delete(names: [String], runMode: Utils.RunMode) throws -> [DeletedObject] {
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
							return DeletedObject(source: cache.location, name: purgeable.name, deleted: true, reason: "")
						}
						return DeletedObject(source: cache.location, name: u.lastPathComponent, deleted: false, reason: "Object not found")
					} else if let scheme = u.scheme {
						return DeletedObject(source: scheme, name: name, deleted: false, reason: "Unsupported URL scheme")
					} else {
						return DeletedObject(source: "vm", name: name, deleted: false, reason: "VM not found")
					}
				}

				return DeletedObject(source: "unknown", name: name, deleted: false, reason: "Unsupported URL")
			}

			return result
		}
	}

	public static func delete(all: Bool, names: [String], runMode: Utils.RunMode) -> DeleteReply {
		var names = names

		do {
			if all {
				names = try StorageLocation(runMode: runMode).list().map { $0.key }
			}

			return DeleteReply(objects: try DeleteHandler.delete(names: names, runMode: runMode), success: true, reason: "Success")
		} catch {
			return DeleteReply(objects: [], success: false, reason: "\(error)")
		}
	}
}
