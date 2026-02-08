import CakedLib
import Dispatch
import Foundation
import GRPC
import GRPCLib
import NIOCore

typealias Caked_ResponseBuildStreamReply = GRPCAsyncResponseStreamWriter<Caked_BuildStreamReply>

struct BuildHandler: CakedCommandAsync {
	var options: BuildOptions
	let responseStream: Caked_ResponseBuildStreamReply

	init(provider: CakedProvider, options: BuildOptions, responseStream: Caked_ResponseBuildStreamReply, context: GRPCAsyncServerCallContext) {
		self.responseStream = responseStream
		self.options = options
	}

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.build = .with {
					$0.builded = .with {
						$0.builded = false
						$0.reason = "\(error)"
					}
				}
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) async -> Caked_Reply {
		do {
			let (stream, continuation) = AsyncStream.makeStream(of: ProgressObserver.ProgressValue.self)
			
			try await withThrowingTaskGroup(of: BuildedReply?.self, returning: Void.self) { group in
				group.addTask {
					let result = await CakedLib.BuildHandler.build(options: self.options, runMode: runMode) { progress in
						continuation.yield(progress)
					}
					
					continuation.finish()

					return result
				}
				
				group.addTask {
					for try await progress in stream {
						if case .progress(let context, let fractionCompleted) = progress {
							let completed = Int(100 * fractionCompleted)

							if completed % 10 == 0 {
								if completed - context.lastCompleted10 >= 10 || completed == 0 || completed == 100 {
									context.lastCompleted10 = completed
								}
							} else if completed % 2 == 0 {
								if completed - context.lastCompleted2 >= 2 {
									context.lastCompleted2 = completed
								}
							}

							try await responseStream.send(.with {
								$0.progress = .with {
									$0.fractionCompleted = Double(fractionCompleted)
									$0.oldFractionCompleted = context.oldFractionCompleted
									$0.lastCompleted10 = Int32(context.lastCompleted10)
									$0.lastCompleted2 = Int32(context.lastCompleted2)
								}
							})
						} else if case .terminated(let result, let message) = progress {
							if case .failure(let error) = result {
								if let message {
									try await responseStream.send(.with {
										$0.terminated = .with {
											$0.failure = "\(message): \(error)"
										}
									})
								} else {
									try await responseStream.send(.with {
										$0.terminated = .with {
											$0.failure = "Installation failed: \(error)"
										}
									})
								}
							} else {
								try await responseStream.send(.with {
									$0.terminated = .with {
										$0.success = message ?? "Installation succeeded"
									}
								})
							}
						} else if case .step(let message) = progress {
							try await responseStream.send(.with {
								$0.step = message
							})
						}
					}
					
					return nil
				}
				
				for try await result in group {
					if let result = result {
						try await responseStream.send(.with {
							$0.builded = result.caked
						})
					}
				}
			}
		} catch {
			return replyError(error: error)
		}

		return .init()
	}
}
