import Foundation
import CakedLib
import GRPCLib

extension DeleteHandler {
	public static func delete(client: CakedServiceClient?, vmURL: URL, runMode: Utils.RunMode) throws -> DeleteReply {
		guard let client, vmURL.isFileURL == false else {
			return self.delete(vmURL: vmURL, runMode: runMode)
		}

		return try DeleteReply(client.delete(.with {
			$0.all = false
			$0.names = .with {
				$0.list = [vmURL.vmName]
			}
		}).response.wait().vms.delete)
	}
}
