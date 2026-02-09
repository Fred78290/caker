import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Build: AsyncGrpcParsableCommand {
	static let configuration = BuildOptions.configuration

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@OptionGroup(title: "Build VM options")
	var buildOptions: BuildOptions

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	mutating func validate() throws {
		try buildOptions.validate()

		if buildOptions.sockets.first(where: { $0.sharedFileDescriptors != nil }) != nil {
			throw ValidationError("Shared file descriptors are not supported, use caked launch instead")
		}
	}

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		return try await withThrowingTaskGroup(of: Void.self, returning: String.self) { group in
			let context: ProgressObserver.ProgressHandlerContext = .init()
			let (stream, continuation) = AsyncStream.makeStream(of: Caked_BuildStreamReply.OneOf_Current?.self)
			var result: String = ""

			group.addTask {
				let stream = try client.build(Caked_BuildRequest(buildOptions: self.buildOptions)) { stream in
					continuation.yield(stream.current)
				}
				
				_ = try await stream.status.get()

				continuation.finish()
			}

			for try await current in stream {
				if case .progress(let progress) = current {
					ProgressObserver.progressHandler(.progress(context, progress.fractionCompleted))
				} else if case .step(let step) = current {
					ProgressObserver.progressHandler(.step(step))
				} else if case .terminated(let status) = current {
					if case .success(let v)? = status.result {
						ProgressObserver.progressHandler(.terminated(.success(self.buildOptions.name), v))
					} else if case .failure(let v)? = status.result {
						ProgressObserver.progressHandler(.terminated(.failure(GrpcError(code: 1, reason: v)), nil))
					}
				} else if case .builded(let builded) = current {
					result = self.format.render(BuildedReply(from: builded))
				}
			}

			return result
		}
	}
}
