import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib
import CakedLib

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
		return try await withTaskGroup { group in
			let context: ProgressObserver.ProgressHandlerContext = .init()
			let vmLocation: VMLocation = StorageLocation(runMode: runMode).location(options.name)
			var (stream, continuation) = AsyncStream.makeStream(of: Caked_BuildStreamReply.OneOf_Current?.self)
			var result: String = ""

			group.addTask {
				let stream = try client.build(Caked_BuildRequest(buildOptions: options)) { stream in
					continuation.yield(stream.current)
				}
				
				_ = try await stream.status.get()

				continuation.finish()
			}

			for try await current in stream {
				if case .progress(let progress) = current {
					progressHandler(.progress(context, progress.fractionCompleted))
				} else if case .step(let step) = current {
					progressHandler(.step(step))
				} else if case .terminated(let status) = current {
					if case .success(let v)? = status.result {
						progressHandler(.terminated(.init(value: vmLocation, error: nil), v))
					} else if case .failure(let v)? = status.result {
						progressHandler(.terminated(.init(value: vmLocation, error: ServiceError(v)), nil))
					}
				} else if case .builded(let builded) = current {
					result = self.format.render(BuildedReply(from: builded))
				}
			}

			return result
		}
	}
}
