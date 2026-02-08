import Foundation
import CakedLib
import GRPCLib

extension BuildHandler {
	public static func build(client: CakedServiceClient?, options: BuildOptions, runMode: Utils.RunMode, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws -> BuildedReply {

		guard let client = client, runMode != .app else {
			return await self.build(options: options, runMode: runMode, queue: queue, progressHandler: progressHandler)
		}

		return try await withThrowingTaskGroup(of: Void.self, returning: BuildedReply.self) { group in
			let context: ProgressObserver.ProgressHandlerContext = .init()
			let vmLocation: VMLocation = StorageLocation(runMode: runMode).location(options.name)
			var (stream, continuation) = AsyncStream.makeStream(of: Caked_BuildStreamReply.OneOf_Current?.self)
			var result: BuildedReply? = nil

			group.addTask {
				let stream = try client.build(Caked_BuildRequest(buildOptions: options)) { stream in
					continuation.yield(stream.current)
				}
				
				_ = try await stream.status.get()

				continuation.finish()
			}

			for try await current in stream {
				if case .progress(let progress) = current {
					await MainActor.run {
						progressHandler(.progress(context, progress.fractionCompleted))
					}
				} else if case .step(let step) = current {
					await MainActor.run {
						progressHandler(.step(step))
					}
				} else if case .terminated(let status) = current {
					if case .success(let v)? = status.result {
						await MainActor.run {
							progressHandler(.terminated(.init(value: vmLocation, error: nil), v))
						}
					} else if case .failure(let v)? = status.result {
						await MainActor.run {
							progressHandler(.terminated(.init(value: vmLocation, error: ServiceError(v)), nil))
						}
					}
				} else if case .builded(let builded) = current {
					result = BuildedReply(from: builded)
				}
			}

			try await group.waitForAll()
			
			guard let result else {
				throw ServiceError("Build failed")
			}

			return result
		}
	}
}
