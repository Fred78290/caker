//
//  DeleteHandler..swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/02/2025.
//
import Foundation
import NIO
import GRPCLib
import TextTable

struct DeleteHandler: CakedCommand {
	var request: Caked_DeleteRequest

	static func tryDeleteLocal(name: String, asSystem: Bool) -> DeleteReply? {
		var vmLocation: VMLocation? = nil

		if let location = try? StorageLocation(asSystem: asSystem).find(name) {
			vmLocation = location
		} else if let u = URL(string: name), u.scheme == "vm" {
			vmLocation = try? StorageLocation(asSystem: asSystem).find(u.host()!)
		}

		if let location = vmLocation {
			if location.status != .running {
				try? FileManager.default.removeItem(at: location.rootURL)
				return DeleteReply(source: "vm", name: location.name, deleted: true, reason: "")
			} else {
				return DeleteReply(source: "vm", name: location.name, deleted: false, reason: "VM is running")
			}
		}

		return nil
	}

	static func delete(names: [String], asSystem: Bool) throws -> [DeleteReply]{		
		return try names.compactMap { name in
			guard let result = tryDeleteLocal(name: name, asSystem: asSystem) else {
				if let u = URL(string: name) {
					var purgeableStorages: [String: CommonCacheImageCache] = [
						CloudImageCache.scheme: try CloudImageCache(asSystem: asSystem),
						RawImageCache.scheme: try RawImageCache(asSystem: asSystem),
						SimpleStreamsImageCache.scheme: try SimpleStreamsImageCache(asSystem: asSystem)
					]

					if true {
						let remoteDb = try Home(asSystem: asSystem).remoteDatabase()

						try remoteDb.keys.forEach {
							purgeableStorages[$0] = try SimpleStreamsImageCache(asSystem: asSystem)
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

	static func delete(all: Bool, names: [String], asSystem: Bool) throws -> [DeleteReply] {
		var names = names

		if all {
			names = try StorageLocation(asSystem: asSystem).list().map { $0.key }
		}

		return try DeleteHandler.delete(names: names, asSystem: asSystem)
	}

	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		try Caked_Reply.with { reply in
			reply.vms = try Caked_VirtualMachineReply.with {
				$0.delete = try Caked_DeleteReply.with {
					$0.objects = try Self.delete(all: self.request.all, names: self.request.names.list, asSystem: asSystem).map {
						$0.toCaked_DeletedObject()
					}
				}
			}
		}
	}
}
