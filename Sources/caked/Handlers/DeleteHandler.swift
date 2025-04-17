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

	static func tryDeleteLocal(name: String) -> DeleteReply? {
		var vmLocation: VMLocation? = nil

		if let location = try? StorageLocation(asSystem: false).find(name) {
			vmLocation = location
		} else if let u = URL(string: name), u.scheme == "vm" {
			vmLocation = try? StorageLocation(asSystem: false).find(u.host()!)
		}

		if let location = vmLocation, location.status != .running {
			if location.status != .running {
				try? FileManager.default.removeItem(at: location.rootURL)
				return DeleteReply(source: "vm", name: location.name, deleted: true)
			} else {
				return DeleteReply(source: "vm", name: location.name, deleted: false)
			}
		}

		return nil
	}

	static func delete(names: [String], asSystem: Bool) throws -> [DeleteReply]{		
		return try names.compactMap { name in
			guard let result = tryDeleteLocal(name: name) else {
				if let u = URL(string: name) {
					var purgeableStorages: [String: CommonCacheImageCache] = [
						CloudImageCache.scheme: try CloudImageCache(),
						RawImageCache.scheme: try RawImageCache(),
						SimpleStreamsImageCache.scheme: try SimpleStreamsImageCache()
					]

					if true {
						let remoteDb = try Home(asSystem: asSystem).remoteDatabase()
	
						try remoteDb.keys.forEach {
							purgeableStorages[$0] = try SimpleStreamsImageCache()
						}
					}

					if let scheme = u.scheme, let cache = purgeableStorages[scheme] {
						let purgeables = try cache.purgeables()

						if let purgeable = purgeables.first(where: { cache.fqn($0).contains(u.absoluteString) }) {
							try purgeable.delete()
							return DeleteReply(source: cache.location, name: purgeable.name(), deleted: true)
						}
						return DeleteReply(source: cache.location, name: u.lastPathComponent, deleted: false)
					} else {
						return DeleteReply(source: u.scheme ?? "unknown", name: name, deleted: false)
					}
				}

				return DeleteReply(source: "unknown", name: name, deleted: false)
			}

			return result
		}
	}

	static func delete(all: Bool, names: [String], asSystem: Bool) throws -> [DeleteReply]{
		var names = names

		if all {
			names = try StorageLocation(asSystem: false).list().map { $0.key }
		}
		
		return try DeleteHandler.delete(names: names, asSystem: asSystem)
	}

	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		try Caked_Reply.with { reply in
			reply.vms = try Caked_VirtualMachineReply.with {
				$0.delete = try Caked_DeleteReply.with {
					$0.objects = try Self.delete(all: self.request.all, names: self.request.names.list, asSystem: runAsSystem).map {
						$0.toCaked_DeletedObject()
					}
				}
			}
		}
	}
}
