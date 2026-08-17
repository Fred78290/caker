//
//  ProvisionHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/08/2026.
//
import ArgumentParser
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPortForwarding
import Semaphore
import Shout
import SystemConfiguration

typealias Caked_ResponseProvisionStreamReply = GRPCAsyncResponseStreamWriter<Caked_ProvisionStreamReply>

struct ProvisionHandler: CakedCommandAsync {
	static let provisionQueue = DispatchQueue(label: "caked.provision-queue")

	let request: Caked_ProvisionRequest
	let responseStream: Caked_ResponseProvisionStreamReply

	init(provider: CakedProvider, request: Caked_ProvisionRequest, responseStream: Caked_ResponseProvisionStreamReply, runMode: Utils.RunMode) throws {
		self.request = request
		self.responseStream = responseStream
	}

	mutating func run(on: any EventLoop, runMode: Utils.RunMode) async -> Caked_Reply {
		do {
			let storageLocation = StorageLocation(runMode: runMode)
			let location: VMLocation = try storageLocation.find(request.name)
			let (stream, continuation) = AsyncStream.makeStream(of: CakedLib.ProvisionHandler.ProgressValue.self)
			
			var lastSentCompleted = -1
			var templateName: String? = nil
			var templateContent: String? = nil
			let promise = on.makePromise(of: Void.self)

			if request.hasProvisionTemplateName {
				templateName = request.provisionTemplateName
			}

			if request.hasProvisionTemplate {
				// request.provisionTemplate is Data; decode to String (UTF-8)
				templateContent = String(data: request.provisionTemplate, encoding: .utf8)
			}

			_ = try await CakedLib.ProvisionHandler.provision(
				location: location,
				storageLocation: storageLocation,
				foreground: false,
				templateName: templateName,
				templateContent: templateContent,
				macosVersion: MacOSVersion(request.macosVersion),
				variables: request.provisionVars.vars.map { value in
					"\(value.key)=\(value.value)"
				},
				runMode: runMode,
				queue: ProvisionHandler.provisionQueue,
				promise: promise
			) { progress in
				continuation.yield(progress)
			}

			promise.futureResult.whenComplete { result in
				continuation.finish()
			}

			for await progress in stream {
				if case .progress(let context, let fractionCompleted) = progress {
					let completed = Int(100 * fractionCompleted)

					guard completed != lastSentCompleted else { continue }
					lastSentCompleted = completed

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
									$0.failure = String(localized: "Provisioning failed: \(error.reason)")
								}
							})
						}
					} else {
						try await responseStream.send(.with {
							$0.terminated = .with {
								$0.success = message ?? String(localized: "Provisioning succeeded")
							}
						})
					}
				} else if case .step(let message) = progress {
					try await responseStream.send(.with {
						$0.step = message
					})
				} else if case .substep(let message) = progress {
					try await responseStream.send(.with {
						$0.substep = message
					})
				} else if case .infos(let message) = progress {
					try await responseStream.send(.with {
						$0.infos = message.caked
					})
				}
			}
		} catch {
			try? await responseStream.send(.with {
				$0.terminated = .with {
					$0.failure = String(localized: "Provisioning failed: \(error.reason)")
				}
			})

			return replyError(error: error)
		}

		return Caked_Reply()
	}
	
	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.provisioned = .with {
					$0.provisioned = .with {
						$0.provisioned = false
						$0.reason = error.reason
					}
				}
			}
		}
	}
}

