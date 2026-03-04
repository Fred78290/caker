import Foundation
import CakedLib
import GRPCLib

extension DeleteHandler {
	public static func delete(client: CakedServiceClient?, rootURL: URL, runMode: Utils.RunMode) throws -> DeleteReply {
		guard let client else {
			return self.delete(rootURL: rootURL, runMode: runMode)
		}

		if rootURL.isFileURL {
			return self.delete(rootURL: rootURL, runMode: runMode)
		}

		guard let host = rootURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		return try DeleteReply(client.delete(.with {
			$0.all = false
			$0.names = .with {
				$0.list = [host]
			}
		}).response.wait().vms.delete)
	}
}
