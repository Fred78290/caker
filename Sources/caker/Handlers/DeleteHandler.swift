import Foundation
import CakedLib
import GRPCLib

extension DeleteHandler {
	public static func delete(client: CakedServiceClient?, vmURL: URL, runMode: Utils.RunMode) throws -> DeleteReply {
		guard let client else {
			return self.delete(vmURL: vmURL, runMode: runMode)
		}

		if vmURL.isFileURL {
			return self.delete(vmURL: vmURL, runMode: runMode)
		}

		guard let host = vmURL.host(percentEncoded: false) else {
			throw ServiceError(String(localized: "Internal error"))
		}

		return try DeleteReply(client.delete(.with {
			$0.all = false
			$0.names = .with {
				$0.list = [host]
			}
		}).response.wait().vms.delete)
	}
}
