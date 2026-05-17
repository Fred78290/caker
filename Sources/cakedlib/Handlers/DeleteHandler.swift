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
	static func tryDeleteLocal(name: String, runMode: Utils.RunMode) -> DeletedObject {
		func doIt(_ location: VMLocation) throws -> DeletedObject {
			if case .running = location.status {
				return DeletedObject(source: "vm", name: location.name, deleted: false, reason: String(localized: "VM is running"))
			} else {
				try FileManager.default.removeItem(at: location.rootURL)
				return DeletedObject(source: "vm", name: location.name, deleted: true, reason: String(localized: "VM deleted"))
			}
		}

		do {
			if let location = try? StorageLocation(runMode: runMode).find(name) {
				return try doIt(location)
			} else if let vmURL = URL(string: name) {
				let location: VMLocation
				
				if vmURL.isFileURL || VMLocation.supportedSchemes.contains(vmURL.scheme) {
					location = try VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode)
				} else {
					return DeletedObject(source: "vm", name: name, deleted: false, reason: String(localized: "VM not found"))
				}

				return try doIt(location)
			}
		} catch {
			return DeletedObject(source: "vm", name: name, deleted: false, reason: error.reason)
		}

		return DeletedObject(source: "unknown", name: name, deleted: false, reason: String(localized: "Unsupported URL"))
	}

	public static func delete(names: [String], runMode: Utils.RunMode) throws -> [DeletedObject] {
		func listRemotes() throws -> [String:SimpleStreamsImageCache] {
			let remoteDb = try Home(runMode: runMode).remoteDatabase()
			var imageCaches: [String: SimpleStreamsImageCache] = [:]
			
			try remoteDb.remote.forEach { (key, value) in
				if let url = URL(string: value), let name = url.host(percentEncoded: false) {
					imageCaches[key] = try SimpleStreamsImageCache(name: name, runMode: runMode)
				}
			}

			return imageCaches
		}

		return try names.compactMap { name in
			if let u = URL(string: name), let scheme = u.scheme, (VMLocation.supportedSchemes.contains(scheme) == false && u.isFileURL == false) {
				let remotes = try listRemotes()
				let purgeableStorages: [String: CommonCacheImageCache] = [
					CloudImageCache.scheme: try CloudImageCache(runMode: runMode),
					RawImageCache.scheme: try RawImageCache(runMode: runMode),
					IPSWCache.scheme: try IPSWCache(runMode: runMode),
					IsoCache.scheme: try IsoCache(runMode: runMode),
					OCIImageCache.scheme: try OCIImageCache(runMode: runMode),
					SimpleStreamsImageCache.scheme: try SimpleStreamsImageCache(runMode: runMode),
				]

				if scheme == OCIImageCache.scheme {
					let contentStore = try PurgeableContentStore(runMode: runMode)
					let purgeables = try contentStore.purgeables()

					if let purgeable = purgeables.first(where: {
						contentStore.fqn($0).contains(u.absoluteString)
					}) {
						try purgeable.delete()

						return DeletedObject(source: scheme, name: purgeable.name, deleted: true, reason: String.empty)
					}
				}
				
				if let cache = purgeableStorages[scheme] {
					let purgeables = try cache.purgeables()
					
					if let purgeable = purgeables.first(where: { cache.fqn($0).contains(u.absoluteString) }) {
						try purgeable.delete()
						return DeletedObject(source: cache.location, name: purgeable.name, deleted: true, reason: String.empty)
					}
					
				} else if let cache = remotes[scheme] {
					if let entry = cache.findCache(fingerprintOrAlias: u.vmName) {
						try cache.deleteCache(fingerprint: entry.fingerprint)

						return DeletedObject(source: cache.location, name: name, deleted: true, reason: String.empty)
					}
				} else {
					return DeletedObject(source: scheme, name: name, deleted: false, reason: String(localized: "Unsupported URL scheme"))
				}

				return DeletedObject(source: scheme, name: u.lastPathComponent, deleted: false, reason: String(localized: "Object not found"))
			}

			return tryDeleteLocal(name: name, runMode: runMode)
		}
	}

	public static func delete(location: VMLocation, runMode: Utils.RunMode) -> DeleteReply {
		do {
			try location.delete()

			return DeleteReply(objects: [
				DeletedObject(source: "vm", name: location.name, deleted: true, reason: String(localized: "VM not found"))
			], success: true, reason: String(localized: "Success"))

		} catch {
			return DeleteReply(objects: [
				DeletedObject(source: "vm", name: location.name, deleted: false, reason: String(localized: "VM not found"))
			], success: false, reason: error.reason)
		}
	}

	public static func delete(name: String, runMode: Utils.RunMode) -> DeleteReply {
		do {
			let location = try StorageLocation(runMode: runMode).find(name)

			return delete(location: location, runMode: runMode)
		} catch {
			return DeleteReply(objects: [
				DeletedObject(source: "vm", name: name, deleted: false, reason: error.reason)
			], success: false, reason: error.reason)
		}
	}

	public static func delete(vmURL: URL, runMode: Utils.RunMode) -> DeleteReply {
		do {
			let location = try VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode)

			return delete(location: location, runMode: runMode)
		} catch {
			return DeleteReply(objects: [
				DeletedObject(source: "vm", name: vmURL.absoluteString, deleted: false, reason: String(localized: "VM not found"))
			], success: false, reason: error.reason)
		}
	}

	public static func delete(all: Bool, names: [String], runMode: Utils.RunMode) -> DeleteReply {
		var names = names

		do {
			if all {
				names = try StorageLocation(runMode: runMode).list().map { $0.key }
			}

			return DeleteReply(objects: try DeleteHandler.delete(names: names, runMode: runMode), success: true, reason: String(localized: "Success"))
		} catch {
			return DeleteReply(objects: [], success: false, reason: error.reason)
		}
	}
}
