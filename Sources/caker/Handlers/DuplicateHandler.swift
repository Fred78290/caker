import Foundation
import CakedLib
import GRPCLib

extension DuplicateHandler {
	public static func duplicate(client: CakedServiceClient?, rootURL: URL, to: String, resetMacAddress: Bool, runMode: Utils.RunMode) throws -> DuplicatedReply {
		guard let client else {
			return self.duplicate(rootURL: rootURL, to: to, resetMacAddress: resetMacAddress, startMode: .attach, runMode: runMode)
		}

		if rootURL.isFileURL {
			return self.duplicate(rootURL: rootURL, to: to, resetMacAddress: resetMacAddress, startMode: .attach, runMode: runMode)
		}

		guard let host = rootURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		return try DuplicatedReply(client.duplicate(.with {
			$0.from = host
			$0.to = to
			$0.resetMacAddress = resetMacAddress
		}).response.wait().vms.duplicated)
	}
}
