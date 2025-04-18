import Foundation
import GRPCLib
import NIOCore
import TextTable

struct RemoteHandler: CakedCommand {
	var request: Caked_RemoteRequest

	static func addRemote(name: String, url: URL, asSystem: Bool) throws -> String {
		let remoteDb = try Home(asSystem: asSystem).remoteDatabase()

		if url.scheme == "https" || url.scheme == "http" {
			guard let _: String = remoteDb.get(name) else {
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

	static func deleteRemote(name: String, asSystem: Bool) throws -> String {
		let remoteDb = try Home(asSystem: asSystem).remoteDatabase()

		if let _: String = remoteDb.get(name) {
			remoteDb.remove(name)
			try remoteDb.save()

			return "remote \(name) deleted"
		}

		throw ServiceError("remote \(name) doesn't exists")
	}

	static func listRemote(asSystem: Bool) throws -> [RemoteEntry] {
		let remoteDb = try Home(asSystem: asSystem).remoteDatabase()

		return try remoteDb.map { (key: String, value: String) in
			RemoteEntry(name: key, url: value)
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> Caked_Reply {
		let message: String

		switch request.command {
		case .list:
			let result = try Self.listRemote(asSystem: asSystem)
			return Caked_Reply.with {
				$0.remotes = Caked_RemoteReply.with {
					$0.list = Caked_ListRemoteReply.with {
						$0.remotes = result.map {
							$0.toCaked_RemoteEntry()
						}
					}
				}
			}
		case .add:
			message = try Self.addRemote(name: request.add.name, url: URL(string: request.add.url)!, asSystem: asSystem)
		case .delete:
			message = try Self.deleteRemote(name: request.delete, asSystem: asSystem)
		default:
			throw ServiceError("Unknown command \(request.command)")
		}

		return Caked_Reply.with {
			$0.remotes = Caked_RemoteReply.with {
				$0.message = message
			}
		}
	}
}
