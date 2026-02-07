import Foundation
import CakedLib
import GRPCLib

extension RemoteHandler {
	public static func listRemote(client: CakedServiceClient?, runMode: Utils.RunMode) throws -> ListRemoteReply {

		guard let client = client, runMode != .app else {
			return self.listRemote(runMode: runMode)
		}

		return try ListRemoteReply(from: client.remote(.with { $0.command = .list}).response.wait().remotes.list)
	}
}
