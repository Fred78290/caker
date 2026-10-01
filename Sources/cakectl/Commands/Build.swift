import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib
import CakedLib

struct Build: AsyncGrpcParsableCommand {
	static let configuration = BuildOptions.build

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Build VM options"))
	var buildOptions: BuildOptions

	mutating func validate() throws {
		try buildOptions.validate(remote: true)

		if buildOptions.sockets.first(where: { $0.sharedFileDescriptors != nil }) != nil {
			throw ValidationError(String(localized: "Shared file descriptors are not supported, use caked launch instead"))
		}
		
		try self.buildOptions.mergeProvisionVars(provisionVars: ProvisionVariablesStore.load())
	}

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		return try await withThrowingTaskGroup(of: Void.self, returning: String.self) { group in
			let context: ProgressObserver.ProgressHandlerContext = .init()
			let (stream, continuation) = AsyncThrowingStream.makeStream(of: Caked_BuildStreamReply.OneOf_Current?.self)
			var result: String = String.empty

			group.addTask {
				Client.sigintSrc.cancel()
				signal(SIGINT, SIG_IGN)

				let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)

				sigintSrc.setEventHandler {
					Task { @MainActor in
						Logger(self).debug("SIGINT received, cancelling provisioning task")

						_ = try? await client.cancelTask(.with {
							$0.id = self.buildOptions.identifier.uuidString
						}).response.get()
					}
					
					sigintSrc.activate()
					sigintSrc.setEventHandler {
						Foundation.exit(128)
					}
				}

				sigintSrc.activate()

				let stream = try client.build(Caked_BuildRequest(buildOptions: self.buildOptions)) { stream in
					continuation.yield(stream.current)
				}
				
				let status = try await stream.status.get()

				if status.isOk {
					continuation.finish()
				} else {
					continuation.finish(throwing: status)
				}
			}

			for try await current in stream {
				if case .progress(let progress) = current {
					ProgressObserver.progressHandler(.progress(context, progress.fractionCompleted))
				} else if case .step(let step) = current {
					ProgressObserver.progressHandler(.step(step))
				} else if case .substep(let step) = current {
					ProgressObserver.progressHandler(.substep(step))
				} else if case .provision(let info) = current {
					ProgressObserver.progressHandler(.provision(.init(info)))
				} else if case .terminated(let status) = current {
					if case .success(let v)? = status.result {
						ProgressObserver.progressHandler(.terminated(.success(self.buildOptions.name), v))
					} else if case .failure(let v)? = status.result {
						ProgressObserver.progressHandler(.terminated(.failure(GrpcError(code: 1, reason: v)), nil))
					}
				} else if case .builded(let builded) = current {
					result = self.options.format.render(BuildedReply(builded))
				}
			}

			return result
		}
	}
}
