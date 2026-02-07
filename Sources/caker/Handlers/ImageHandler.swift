import Foundation
import CakedLib
import GRPCLib

extension ImageHandler {
	public static func listImage(client: CakedServiceClient?, remote: String, runMode: Utils.RunMode) async -> ListImagesInfoReply {
		guard let client = client, runMode != .app else {
			return await self.listImage(remote: remote, runMode: runMode)
		}

		do {
			return try await ListImagesInfoReply(from: client.image(.with {
				$0.command = .list
				$0.name = remote
			}).response.get().images.list)
		} catch {
			return ListImagesInfoReply(infos: [], success: false, reason: "\(error)")
		}
	}
}
