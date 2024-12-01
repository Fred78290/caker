import Foundation
import GRPCLib

struct RemoteHandler: CakedCommand {
	var request: Caked_RemoteRequest
	
	static func addRemote(name: String, url: URL) throws -> String {
		return ""
	}

	static func deleteRemote(name: String) throws -> String {
		return ""
	}

	static func listRemote() throws -> String {
		return ""
	}

	func run(asSystem: Bool) async throws -> String {
		switch request.command {
		case .add:
			return try Self.addRemote(name: request.add.name, url: URL(string: request.add.url)!)
		case .delete:
			return try Self.deleteRemote(name: request.delete)
		case .list:
			return try Self.listRemote()
		default:
			throw ServiceError("Unknown command \(request.command)")
		}
	}
}
