import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIOCore

typealias Caked_ResponseLaunchStreamReply = GRPCAsyncResponseStreamWriter<Caked_LaunchStreamReply>

struct LaunchHandler: CakedCommandAsync {
	var options: BuildOptions
	let startMode: CakedLib.StartHandler.StartMode
	let gcd: Bool
	var waitIPTimeout = 180
	let responseStream: Caked_ResponseLaunchStreamReply
	let handler: () async throws -> Void

	init(request: Caked_LaunchRequest, gcd: Bool, responseStream: Caked_ResponseLaunchStreamReply, context: GRPCAsyncServerCallContext, handler: @escaping () async throws -> Void) throws {
		self.options = try request.options.buildOptions()
		self.gcd = gcd
		self.startMode = .service
		self.waitIPTimeout = request.hasWaitIptimeout ? Int(request.waitIptimeout) : 180
		self.responseStream = responseStream
		self.handler = handler
	}

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.launched = .with {
					$0.name = self.options.name
					$0.launched = false
					$0.reason = error.reason
				}
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) async -> Caked_Reply {
		do {
			let (stream, continuation) = AsyncStream.makeStream(of: ProgressObserver.ProgressValue.self)
			
			try await withThrowingTaskGroup(of: LaunchReply?.self, returning: Void.self) { group in
				group.addTask {
					defer {
						continuation.finish()
					}

					let storageLocation: StorageLocation = StorageLocation(runMode: runMode)
					let result = await CakedLib.BuildHandler.build(options: options, runMode: runMode) { progress in
						continuation.yield(progress)
					}

					if result.builded == false {
						return LaunchReply(name: result.name, ip: String.empty, launched: false, reason: result.reason)
					}

					do {
						try await self.handler()

						let reply = try CakedLib.StartHandler.startVM(on: Utilities.group.next(), location: storageLocation.find(options.name), screenSize: nil, vncPassword: nil, vncPort: nil, waitIPTimeout: 180, startMode: startMode, gcd: self.gcd, runMode: runMode)

						return LaunchReply(name: reply.name, ip: reply.ip, launched: reply.started, reason: reply.reason)
					} catch {
						return LaunchReply(name: result.name, ip: String.empty, launched: false, reason: error.reason)
					}
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
											$0.failure = String(localized: "Installation failed: \(error.reason)")
										}
									})
								}
							} else {
								try await responseStream.send(.with {
									$0.terminated = .with {
										$0.success = message ?? String(localized: "Installation succeeded")
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
						if result.launched {
							try await self.handler()
						}

						try await responseStream.send(.with {
							$0.launched = result.caked
						})
					}
				}
			}
		} catch {
			try? await responseStream.send(.with {
				$0.launched = .with {
					$0.name = self.options.name
					$0.launched = false
					$0.reason = error.reason
				}
			})
		}

		return .init()
	}
}
