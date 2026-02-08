import Foundation
import CakedLib
import GRPCLib

extension BuildHandler {
	public static func build(client: CakedServiceClient?, options: BuildOptions, runMode: Utils.RunMode, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws -> BuildedReply {

		guard let client = client, runMode != .app else {
			return await self.build(options: options, runMode: runMode, queue: queue, progressHandler: progressHandler)
		}

		return try await BuildedReply(from: client.build(Caked_BuildRequest(buildOptions: options)).response.get().vms.builded)
	}
}
