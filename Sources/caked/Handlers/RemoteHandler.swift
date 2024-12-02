import Foundation
import GRPCLib

struct RemoteEntry: Codable {
	let name: String
	let url: String
}

struct RemoteHandler: CakedCommand {
	var request: Caked_RemoteRequest

	static func addRemote(name: String, url: URL, asSystem: Bool) throws -> String {
		let home: Home = try Home(asSystem: asSystem)
		var remoteDb = try home.remoteDatabase()

		if url.scheme == "https" || url.scheme == "http" {
			guard let _: String = remoteDb[name] else {
				remoteDb[name] = url.absoluteString
				try remoteDb.write(to: home.remoteDb)

				return "remote \(name) added"
			}

			throw ServiceError("remote \(name) already exists")
		} else if let scheme = url.scheme {
			throw ServiceError("remote unsupported scheme: \(scheme) for \(url)")
		}

		throw ServiceError("remote unsupported url: \(url)")
	}

	static func deleteRemote(name: String, asSystem: Bool) throws -> String {
		let home: Home = try Home(asSystem: asSystem)
		var remoteDb = try home.remoteDatabase()

		if let _: String = remoteDb[name] {
			remoteDb.removeValue(forKey: name)
			try remoteDb.write(to: home.remoteDb)

			return "remote \(name) deleted"
		}

		throw ServiceError("remote \(name) doesn't exists")
	}

	static func listRemote(asSystem: Bool) throws -> [RemoteEntry] {
		let home: Home = try Home(asSystem: asSystem)
		let remoteDb = try home.remoteDatabase()

		return remoteDb.map { (key: String, value: String) in
			RemoteEntry(name: key, url: value)
		}
	}

	func run(asSystem: Bool) async throws -> String {
		switch request.command {
		case .add:
			return try Self.addRemote(name: request.add.name, url: URL(string: request.add.url)!, asSystem: runAsSystem)
		case .delete:
			return try Self.deleteRemote(name: request.delete, asSystem: runAsSystem)
		case .list:
			let format = request.format == .text ? Format.text : Format.json
			return format.renderList(try Self.listRemote(asSystem: runAsSystem))
		default:
			throw ServiceError("Unknown command \(request.command)")
		}
	}
}
