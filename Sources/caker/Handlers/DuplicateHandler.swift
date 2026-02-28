import Foundation
import CakedLib
import GRPCLib

extension DuplicateHandler {
	public static func duplicate(client: CakedServiceClient?, from: String, to: String, resetMacAddress: Bool, runMode: Utils.RunMode) throws -> DuplicatedReply {

		guard let client = client, runMode != .app else {
			return self.duplicate(from: from, to: to, resetMacAddress: resetMacAddress, startMode: .attach, runMode: runMode)
		}

		return try DuplicatedReply(from: client.duplicate(.with {
			$0.from = from
			$0.to = to
			$0.resetMacAddress = resetMacAddress
		}).response.wait().vms.duplicated)
	}
}
