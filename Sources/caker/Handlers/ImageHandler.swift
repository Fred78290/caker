import Foundation
import CakedLib
import GRPCLib

extension ImageHandler {
	public static func listImage(client: CakedServiceClient?, remote: String, runMode: Utils.RunMode) async throws -> ListImagesInfoReply {
		guard let client = client else {
			return await self.listImage(remote: remote, runMode: runMode)
		}

		return try await ListImagesInfoReply(client.image(.with {
			$0.command = .list
			$0.name = remote
		}).response.get().images.list)
	}
}
