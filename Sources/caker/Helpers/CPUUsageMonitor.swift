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
	@Published var memoryInfos = MemoryInfo()

	private let name: String
	private var isMonitoring: Bool = false
	private var stream: AsyncThrowingStreamCakeAgentCurrentUsageReply? = nil

#if DEBUG
	private let logger = Logger("CPUUsageMonitor")
#endif

	deinit {
		self.cancel()
	}

	init(name: String) {
		self.name = name
	}

	func start() async {
		await monitorCurrentUsage()
	}

	func cancel(_line: UInt = #line, _file: String = #file) {
		guard self.isMonitoring else {
			return
		}

		self.isMonitoring = false

		#if DEBUG
			self.logger.debug("Cancel monitoring current CPU usage, VM: \(self.name), \(_file):\(_line)")
		#endif

		if let stream {
			stream.continuation.finish(throwing: GRPCStatus(code: .cancelled, message: "Cancelled"))
		}
	}

	func monitorCurrentUsage() async {
		guard self.isMonitoring == false else {
			return
		}

		#if DEBUG
		let debugLogger = self.logger

		debugLogger.debug("Start monitoring current CPU usage, VM: \(self.name)")
		#endif

		await withTaskCancellationHandler(operation: {
			let taskQueue = TaskQueue(label: "CakeAgent.CPUUsageMonitor.\(self.name)")
			var helper: CakeAgentHelper! = nil

			self.isMonitoring = true

			func performAgentHealthCheck() -> AsyncThrowingStreamCakeAgentCurrentUsageReply {
				return taskQueue.dispatchStream { [weak self] (continuation: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>.Continuation) in
					guard let self = self else {
						return
					}

					do {
						let infos = try helper.info(callOptions: CallOptions(timeLimit: .timeout(.seconds(10))))

						DispatchQueue.main.sync {
							self.handleAgentHealthCurrentUsage(usage: infos)
						}

						helper.currentUsage(frequency: 1, callOptions: CallOptions(timeLimit: .none), continuation: continuation)
					} catch {
						continuation.finish(throwing: error)
					}
				}
			}

			while Task.isCancelled == false && self.isMonitoring {

				do {
					helper = try self.createHelper()

					self.stream = performAgentHealthCheck()

					for try await currentUsage in stream!.stream {
						await self.handleAgentHealthCurrentUsage(usage: currentUsage)
					}
					
					break
				} catch {
					if self.isMonitoring {
						try? await helper?.close().get()

						self.stream = nil
						self.cpuInfos.cores = []

						guard self.handleAgentHealthCheckFailure(error: error) else {
							return
						}
						#if DEBUG
							debugLogger.debug("Monitoring agent not ready, VM: \(self.name), waiting...")
						#endif
						try? await Task.sleep(nanoseconds: 1_000_000_000)
					}
				}
			}

			taskQueue.close()
			try? await helper?.close().get()

			self.isMonitoring = false
			self.stream = nil

#if DEBUG
			debugLogger.debug("Monitoring ended, VM: \(self.name)")
#endif
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
		self.memoryInfos.update(infos: usage.memory)
	}

	@MainActor
	private func handleAgentHealthCurrentUsage(usage: InfoReply) {
		self.cpuInfos.update(from: usage.cpuInfo)
		self.memoryInfos.update(infos: usage.memory)
	}

	private func handleAgentHealthCheckFailure(error: Error) -> Bool {
#if DEBUG
		self.logger.debug("Agent monitoring: VM \(self.name) is not ready")
#endif

		func handleGrpcStatus(_ grpcError: GRPCStatus) -> Bool {
			switch grpcError.code {
			case .unavailable:
				// These could be temporary - continue monitoring
				self.logger.info("Agent monitoring: VM \(self.name) agent unvailable")
				return true
			case .cancelled:
				// These could be temporary - continue monitoring
				self.logger.info("Agent monitoring: VM \(self.name) agent cancelled")
			case .deadlineExceeded:
				// Timeout - VM might be under heavy load
				self.logger.info("Agent monitoring: VM \(self.name) agent timeout")
				return true
			case .unimplemented:
				// unimplemented - Agent is too old, need update
				self.logger.info("Agent monitoring: VM \(self.name) agent is too old, need update")
				return true
			default:
				// Other errors might indicate serious issues
				self.logger.error("Agent monitoring: VM \(self.name) agent error: \(grpcError)")
			}

			return false
		}

		if let grpcError = error as? any GRPCStatusTransformable {
			return handleGrpcStatus(grpcError.makeGRPCStatus())
		} else if let grpcError = error as? GRPCStatus {
			return handleGrpcStatus(grpcError)
		} else {
			// Agent is not responding - could indicate VM issues
			self.logger.error("Agent monitoring: VM \(self.name) agent not responding: \(error)")  // Check if it's a permanent failure (connection refused, etc.)
		}
		
		return false
	}

	private func createHelper(connectionTimeout: Int64 = 5) throws -> CakeAgentHelper {
		let eventLoop = Utilities.group.next()

		let client = try Utilities.createCakeAgentClient(
			on: eventLoop.next(),
			runMode: .app,
			name: name,
			connectionTimeout: connectionTimeout,
			retries: .unlimited// .upTo(1)
		)

		return CakeAgentHelper(on: eventLoop, client: client)
	}
}
