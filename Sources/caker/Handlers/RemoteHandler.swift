import Foundation
import CakedLib
import GRPCLib

extension RemoteHandler {
	public static func listRemote(client: CakedServiceClient?, runMode: Utils.RunMode) throws -> ListRemoteReply {

		guard let client = client else {
			return self.listRemote(runMode: runMode)
		}

		return try ListRemoteReply(client.remote(.with { $0.command = .list}).response.wait().remotes.list)
	}

	public static func addRemote(client: CakedServiceClient?, name: String, url: URL, runMode: Utils.RunMode) async throws -> CreateRemoteReply {
		guard let client = client else {
			return self.addRemote(name: name, url: url, runMode: runMode)
		}

		return try await CreateRemoteReply(client.remote(.with {
			$0.command = .add
			$0.addRequest = .with {
				$0.name = name
				$0.url = url.absoluteString
			}
		}).response.get().remotes.created)
	}

	public static func deleteRemote(client: CakedServiceClient?, name: String, runMode: Utils.RunMode) throws -> DeleteRemoteReply {
		guard let client = client else {
			return self.deleteRemote(name: name, runMode: runMode)
		}
		
		return try DeleteRemoteReply(client.remote(.with {
			$0.command = .delete
			$0.deleteRequest = name
		}).response.wait().remotes.deleted)
	}
}
