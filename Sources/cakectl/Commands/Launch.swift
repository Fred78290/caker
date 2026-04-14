import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Launch: AsyncGrpcParsableCommand {
	static let configuration = BuildOptions.launch

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Launch VM options"))
	var buildOptions: BuildOptions

	@Option(help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout = 180

	mutating func validate() throws {
		try buildOptions.validate(remote: true)

		if buildOptions.sockets.first(where: { $0.sharedFileDescriptors != nil }) != nil {
			throw ValidationError(String(localized: "Shared file descriptors are not supported, use caked launch instead"))
		}
	}

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		return try await withThrowingTaskGroup(of: Void.self, returning: String.self) { group in
			let context: ProgressObserver.ProgressHandlerContext = .init()
			let (stream, continuation) = AsyncStream.makeStream(of: Caked_LaunchStreamReply.OneOf_Current?.self)
			var result: String = String.empty

			group.addTask {
				let stream = try client.launch(Caked_LaunchRequest(command: self)) { stream in
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
				} else if case .launched(let launched) = current {
					result = self.options.format.render(LaunchReply(launched))
				}
			}

			return result
		}
	}
}
