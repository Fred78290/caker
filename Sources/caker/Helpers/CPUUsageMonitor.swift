//
//  CPUUsageMonitor.swift
//  Caker
//
//  Created by Frederic BOLTZ on 10/01/2026.
//
import Foundation
import CakeAgentLib
import CakedLib
import GRPC
import NIO
import SwiftUI

typealias AsyncThrowingStreamCakeAgentCurrentUsageReply = (stream: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>, continuation: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>.Continuation)

final class CPUUsageMonitor: ObservableObject, Observable {
	@Published var cpuInfos = CpuInfos()

	private let name: String
	private let taskQueue = TaskQueue()
	private let eventLoop: EventLoop
	private var stream: AsyncThrowingStreamCakeAgentCurrentUsageReply? = nil

#if DEBUG
	private let logger = Logger("CPUUsageMonitor")
#endif

	deinit {
		taskQueue.close()
	}

	init(name: String) {
		self.name = name
		self.eventLoop = Utilities.group.next()
	}

	func start() async {
		await monitorCurrentUsage()
	}

	func cancel() {
		taskQueue.close()
	}

	func monitorCurrentUsage() async {
		#if DEBUG
		let debugLogger = self.logger

		debugLogger.debug("Start monitoring current CPU usage, VM: \(self.name)")
		#endif

		await withTaskCancellationHandler(operation: {
			while Task.isCancelled == false {
				self.stream = self.performAgentHealthCheck()

				do {
					for try await currentUsage in stream!.stream {
						await self.handleAgentHealthCurrentUsage(usage: currentUsage)
					}
				} catch {
					self.stream = nil

					guard self.handleAgentHealthCheckFailure(error: error) else {
						return
					}
					#if DEBUG
						debugLogger.debug("Monitoring agent not ready, VM: \(self.name), waiting...")
					#endif
					try? await Task.sleep(nanoseconds: 1_000_000_000)
				}
			}
		}, onCancel: {
		#if DEBUG
			debugLogger.debug("Monitoring canceled, VM: \(self.name)")
		#endif
			self.stream?.continuation.finish()
		})
	}

	@MainActor
	private func handleAgentHealthCurrentUsage(usage: CakeAgent.CurrentUsageReply) {
		self.cpuInfos.update(from: usage.cpuInfos)
	}

	@MainActor
	private func handleAgentHealthCurrentUsage(usage: InfoReply) {
		self.cpuInfos.update(from: usage.cpuInfo)
	}

	private func handleAgentHealthCheckFailure(error: Error) -> Bool {
#if DEBUG
		self.logger.debug("Agent monitoring: VM \(self.name) is not ready")
#endif

		func handleGrpcStatus(_ grpcError: GRPCStatus) {
			switch grpcError.code {
			case .unavailable:
				// These could be temporary - continue monitoring
				self.logger.info("Agent monitoring: VM \(self.name) agent unvailable")
				break
			case .cancelled:
				// These could be temporary - continue monitoring
				self.logger.info("Agent monitoring: VM \(self.name) agent cancelled")
				break
			case .deadlineExceeded:
				// Timeout - VM might be under heavy load
				self.logger.info("Agent monitoring: VM \(self.name) agent timeout")
			default:
				// Other errors might indicate serious issues
				self.logger.error("Agent monitoring: VM \(self.name) agent error: \(grpcError)")
			}
		}

		if let grpcError = error as? any GRPCStatusTransformable {
			handleGrpcStatus(grpcError.makeGRPCStatus())
		} else if let grpcError = error as? GRPCStatus {
			handleGrpcStatus(grpcError)
		} else {
			// Agent is not responding - could indicate VM issues
			self.logger.error("Agent monitoring: VM \(self.name) agent not responding: \(error)")  // Check if it's a permanent failure (connection refused, etc.)
			return false
		}
		
		return true
	}

	private func createHelper(connectionTimeout: Int64 = 5) throws -> CakeAgentHelper {
		let client = try Utilities.createCakeAgentClient(
			on: self.eventLoop.next(),
			runMode: .app,
			name: name,
			connectionTimeout: connectionTimeout,
			retries: .unlimited// .upTo(1)
		)

		return CakeAgentHelper(on: self.eventLoop, client: client)
	}

	private func performAgentHealthCheck() -> AsyncThrowingStreamCakeAgentCurrentUsageReply {
		return taskQueue.dispatchStream { (continuation: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>.Continuation) in
			let stream: CakeAgentCurrentUsageStream
			let name = self.name
			let logger = self.logger

			do {
				let helper = try self.createHelper()

				defer {
					helper.close(promise: self.eventLoop.makePromise())
				}

				let infos = try helper.info(callOptions: CallOptions(timeLimit: .timeout(.seconds(10))))

				DispatchQueue.main.sync {
					self.handleAgentHealthCurrentUsage(usage: infos)
				}

				try helper.currentUsage(frequency: 1) { reply in
					continuation.yield(reply)
				}
				//helper.currentUsage(frequency: 1, callOptions: CallOptions(timeLimit: .none), continuation: continuation)

				/*stream = helper.client.currentUsage(CakeAgent.CurrentUsageRequest.with { $0.frequency = 1 }, callOptions: CallOptions(timeLimit: .none)) { reply in
					continuation.yield(reply)
				}
				
				let subchannel = try stream.subchannel.wait()
				
				continuation.onTermination = { _ in
					continuation.onTermination = nil
					subchannel.close(promise: nil)
				}
				
#if DEBUG
				self.logger.debug("Agent monitoring: VM \(self.name) is ready")
#endif

				stream.status.whenComplete { result in
					continuation.onTermination = nil

					switch result {
					case .failure(let err):
#if DEBUG
						logger.debug("Exit agent monitoring VM \(name) on error: \(err)")
#endif

						subchannel.close(promise: nil)
						continuation.finish(throwing: err)
					case .success(let status):
#if DEBUG
						logger.debug("Exit agent monitoring: VM \(name) code: \(status.code)")
#endif
						if status.code != .ok {
							subchannel.close(promise: nil)
							continuation.finish(throwing: status)
						}
					}
				}*/
			} catch {
				continuation.finish(throwing: error)
			}
		}
	}
}
