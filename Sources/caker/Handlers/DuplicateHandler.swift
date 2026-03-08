import Foundation
import CakedLib
import GRPCLib

extension DuplicateHandler {
	public static func duplicate(client: CakedServiceClient?, vmURL: URL, to: String, resetMacAddress: Bool, runMode: Utils.RunMode) throws -> DuplicatedReply {
		guard let client else {
			return self.duplicate(vmURL: vmURL, to: to, resetMacAddress: resetMacAddress, startMode: .attach, runMode: runMode)
		}

		if vmURL.isFileURL {
			return self.duplicate(vmURL: vmURL, to: to, resetMacAddress: resetMacAddress, startMode: .attach, runMode: runMode)
		}

		guard let host = vmURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		return try DuplicatedReply(client.duplicate(.with {
			$0.from = host
			$0.to = to
			$0.resetMacAddress = resetMacAddress
		}).response.wait().vms.duplicated)
	}
}
