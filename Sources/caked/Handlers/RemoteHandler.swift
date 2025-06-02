import Foundation
import GRPCLib
import NIOCore
import TextTable

struct RemoteHandler: CakedCommand {
	var request: Caked_RemoteRequest

	static func addRemote(name: String, url: URL, runMode: Utils.RunMode) throws -> String {
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

	static func deleteRemote(name: String, runMode: Utils.RunMode) throws -> String {
		let remoteDb = try Home(runMode: runMode).remoteDatabase()

		if remoteDb.get(name) != nil {
			remoteDb.remove(name)
			try remoteDb.save()

			return "remote \(name) deleted"
		}

		throw ServiceError("remote \(name) doesn't exists")
	}

	static func listRemote(runMode: Utils.RunMode) throws -> [RemoteEntry] {
		let remoteDb = try Home(runMode: runMode).remoteDatabase()

		return try remoteDb.map { (key: String, value: String) in
			RemoteEntry(name: key, url: value)
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		let message: String

		switch request.command {
		case .list:
			let result = try Self.listRemote(runMode: runMode)
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
			message = try Self.addRemote(name: request.addRequest.name, url: URL(string: request.addRequest.url)!, runMode: runMode)
		case .delete:
			message = try Self.deleteRemote(name: request.deleteRequest, runMode: runMode)
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
