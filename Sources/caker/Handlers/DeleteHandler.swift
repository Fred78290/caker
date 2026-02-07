import Foundation
import CakedLib
import GRPCLib

extension DeleteHandler {
	public static func delete(client: CakedServiceClient?, name: String, runMode: Utils.RunMode) throws -> DeleteReply {

		guard let client = client, runMode != .app else {
			return self.delete(all: false, names: [name], runMode: runMode)
		}

		return try DeleteReply(from: client.delete(.with {
			$0.all = false
			$0.names = .with {
				$0.list = [name]
			}
		}).response.wait().vms.delete)
	}
}
