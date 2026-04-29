import Foundation
import CakedLib
import GRPCLib

extension DuplicateHandler {
	public static func duplicate(client: CakedServiceClient?, vmURL: URL, to: String, resetMacAddress: Bool, runMode: Utils.RunMode) throws -> DuplicatedReply {
		guard let client, vmURL.isFileURL == false else {
			return self.duplicate(vmURL: vmURL, to: to, resetMacAddress: resetMacAddress, runMode: runMode)
		}

		return try DuplicatedReply(client.duplicate(.with {
			$0.from = vmURL.vmName
			$0.to = to
			$0.resetMacAddress = resetMacAddress
		}).response.wait().vms.duplicated)
	}
}
