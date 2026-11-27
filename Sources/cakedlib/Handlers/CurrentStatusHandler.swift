//
//  CurrentStatusHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/02/2026.
//
import Foundation
import GRPCLib
import GRPC
import CakeAgentLib
import NIO
import FileMonitor
import FileMonitorShared
import Combine
import SwiftUI

typealias AsyncThrowingStreamCakedCurrentStatusReply = (
	stream: AsyncThrowingStream<Caked_CurrentStatus, Error>,
	continuation: AsyncThrowingStream<Caked_CurrentStatus, Error>.Continuation
)

typealias AsyncThrowingStreamCakeAgentCurrentUsageReply = (
	stream: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>,
	continuation: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>.Continuation
)

public extension VMLocation.Status {
	init(_ from: Caked_VirtualMachineStatus) {
		switch from {
		case .stopped:
			self = .stopped
		case .running:
			self = .running(.caked)
		case .paused:
			self = .paused
		case .provisioning:
			self = .running(.provision)
		case .restarting:
			self = .running(.restart)
		default:
			self = .stopped
		}
	}
}

public extension Caked_VirtualMachineStatus {
	init(_ from: VMLocation.Status) {
		switch from {
		case .running(let mode):
			switch mode {
			case .none:
				self = .error
			case .caked:
				self = .running
			case .caker:
				self = .running
			case .provision:
				self = .provisioning
			case .restart:
				self = .restarting
			}
		case .paused:
			self = .paused
		case .stopped:
			self = .stopped
		}
	}
}

public struct CurrentStatusHandler {
	public typealias AsyncThrowingStreamCurrentStatusReplyYield = AsyncThrowingStream<CurrentStatusReply, Error>.Continuation
	
	private class CurrentUsageWatcher {
		/// The status stream task, the monitor task and cancellation all reach this state: every access goes through `lock`.
		private let lock = NSLock()
		private var monitoring: Bool = false
		/// Identifies the latest `monitorCurrentUsage()` run. A run cancelled by a restart can still be unwinding when
		/// the next one starts: only the current run may touch `monitoring`/`stream`, so a stale one can't clear them.
		private var generation: UInt64 = 0
		private var stream: AsyncThrowingStreamCakeAgentCurrentUsageReply? = nil
		private let location: VMLocation
		private let runMode: Utils.RunMode
		private let continuation: AsyncThrowingStream<Caked_CurrentStatus, Error>.Continuation
		private let logger = Logger("CurrentUsageWatcher")

		init(location: VMLocation, runMode: Utils.RunMode, continuation: AsyncThrowingStream<Caked_CurrentStatus, Error>.Continuation) {
			self.location = location
			self.continuation = continuation
			self.runMode = runMode
		}

		func start() async {
			await monitorCurrentUsage()
		}

		internal var isMonitoring: Bool {
			self.lock.withLock { self.monitoring }
		}

		/// Marks a new run as started, unless one already is: returns its generation, or nil.
		private func beginRun() -> UInt64? {
			self.lock.withLock {
				guard self.monitoring == false else {
					return nil
				}

				self.monitoring = true
				self.generation &+= 1

				return self.generation
			}
		}

		/// True while `generation` is the current run and it hasn't been cancelled.
		private func isActive(_ generation: UInt64) -> Bool {
			self.lock.withLock { self.monitoring && self.generation == generation }
		}

		/// Registers the stream of `generation`, only while that run is still current and not cancelled: `cancel()` may
		/// have run while the helper was connecting, and found no stream to finish. Returns false when it was refused.
		private func registerStream(_ stream: AsyncThrowingStreamCakeAgentCurrentUsageReply, for generation: UInt64) -> Bool {
			self.lock.withLock {
				guard self.monitoring && self.generation == generation else {
					return false
				}

				self.stream = stream

				return true
			}
		}

		private func clearStream(for generation: UInt64) {
			self.lock.withLock {
				if self.generation == generation {
					self.stream = nil
				}
			}
		}

		/// Publishes a usage sample of `generation` only while it is the current, active run. Checked and yielded under the
		/// lock, so `cancel()`/`beginRun()` can't change ownership in between: a sample of a run cancelled by a restart
		/// would otherwise reach the consumer and mark the agent ready.
		private func publish(_ status: Caked_CurrentStatus, for generation: UInt64) {
			self.lock.withLock {
				if self.monitoring && self.generation == generation {
					self.continuation.yield(status)
				}
			}
		}

		/// Ends `generation` if it is still the current run; a stale run leaves the state of its replacement alone.
		private func endRun(_ generation: UInt64) {
			self.lock.withLock {
				if self.generation == generation {
					self.monitoring = false
					self.stream = nil
				}
			}
		}

		func cancel() {
			let (wasMonitoring, stream) = self.lock.withLock {
				let wasMonitoring = self.monitoring

				self.monitoring = false

				return (wasMonitoring, self.stream)
			}

			guard wasMonitoring else {
				return
			}

			self.logger.debug("Cancel monitoring current CPU usage, VM: \(self.location.name)")

			stream?.continuation.finish(throwing: CancellationError())
		}

		private func handleAgentHealthCurrentUsage(usage: CakeAgent.CurrentUsageReply, for generation: UInt64) {
			self.publish(.with {
				$0.name = self.location.name
				$0.usage = .with {
					$0.cpuCount = usage.cpuCount
					
					if usage.hasCpuInfos {
						$0.cpuInfos = usage.cpuInfos.caked
					}
					
					if usage.hasMemory {
						$0.memory = .with {
							let mem = usage.memory
							
							$0.total = mem.total
							$0.free = mem.free
							$0.used = mem.used
							$0.swapTotal = mem.swapTotal
							$0.swapFree = mem.swapFree
							$0.swapUsed = mem.swapUsed
						}
					}
				}
			}, for: generation)
		}

		private func handleAgentHealthCurrentUsage(usage: InfoReply, for generation: UInt64) {
			let usage = usage.caked

			self.publish(.with {
				$0.name = self.location.name
				$0.usage = .with {
					$0.cpuCount = usage.cpuCount
					
					if usage.hasCpu {
						$0.cpuInfos = usage.cpu
					}
					
					if usage.hasMemory {
						$0.memory = usage.memory
					}
				}
			}, for: generation)
		}

		func monitorCurrentUsage() async {
			guard let generation = self.beginRun() else {
				return
			}

			self.logger.debug("Start monitoring current CPU usage, VM: \(self.location.name)")

			await withTaskCancellationHandler(operation: {
				let taskQueue = TaskQueue(label: "CakeAgent.CurrentUsageWatcher.\(self.location.name)")
				var helper: CakeAgentHelper! = nil

				func performAgentHealthCheck() -> AsyncThrowingStreamCakeAgentCurrentUsageReply {
					return taskQueue.dispatchStream { [weak self] (continuation: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>.Continuation) in
						guard let self = self else {
							return
						}

						do {
							let infos = try helper.info(callOptions: CallOptions(timeLimit: .timeout(.seconds(10))))

							self.logger.debug("Monitoring agent is ready, VM: \(self.location.name)")

							self.handleAgentHealthCurrentUsage(usage: infos, for: generation)

							helper.currentUsage(frequency: 1, callOptions: CallOptions(timeLimit: .none), continuation: continuation)
						} catch {
							continuation.finish(throwing: error)
						}
					}
				}

				func close() {
					
				}

				while Task.isCancelled == false && self.isActive(generation) {
					do {
						helper = try self.createCakeAgentHelper()

						let stream = performAgentHealthCheck()

						// Refused: the run was cancelled or replaced meanwhile. Finishing the stream ends the loop below through
						// the CancellationError path, and `endRun` leaves a replacement's state alone.
						if self.registerStream(stream, for: generation) == false {
							stream.continuation.finish(throwing: CancellationError())
						}

						for try await currentUsage in stream.stream {
							handleAgentHealthCurrentUsage(usage: currentUsage, for: generation)
						}

						break
					} catch is CancellationError {
						self.endRun(generation)
					} catch {
						if self.isActive(generation) {
							try? await helper?.close().get()

							self.clearStream(for: generation)

							// Not `return`: the cleanup below must run, or the run would stay marked as monitoring for ever
							guard self.handleAgentHealthCheckFailure(error: error) else {
								break
							}
							self.logger.debug("Monitoring agent not ready, VM: \(self.location.name), waiting...")
							try? await Task.sleep(nanoseconds: 1_000_000_000)
						}
					}
				}

				taskQueue.close()
				try? await helper?.close().get()

				self.endRun(generation)

				self.logger.debug("Monitoring ended, VM: \(self.location.name)")
			}, onCancel: {
				self.logger.debug("Monitoring canceled, VM: \(self.location.name)")

				// Only this run's own stream: a newer run's must not be finished by a stale cancellation
				let stream = self.lock.withLock { self.generation == generation ? self.stream : nil }

				stream?.continuation.finish(throwing: CancellationError())
			})
		}

		private func handleAgentHealthCheckFailure(error: Error) -> Bool {
			self.logger.debug("Agent monitoring: VM \(self.location.name) is not ready")

			func handleGrpcStatus(_ grpcError: GRPCStatus) -> Bool {
				switch grpcError.code {
				case .unavailable:
					// These could be temporary - continue monitoring
					self.logger.trace("Agent monitoring: VM \(self.location.name) agent unvailable")
					return true
				case .cancelled:
					// These could be temporary - continue monitoring
					self.logger.debug("Agent monitoring: VM \(self.location.name) agent cancelled")
				case .deadlineExceeded:
					// Timeout - VM might be under heavy load
					self.logger.debug("Agent monitoring: VM \(self.location.name) agent timeout")
					return true
				case .unimplemented:
					// unimplemented - Agent is too old, need update
					self.logger.warn("Agent monitoring: VM \(self.location.name) agent is too old, need update")
					return true
				default:
					// Other errors might indicate serious issues
					self.logger.error("Agent monitoring: VM \(self.location.name) agent error: \(grpcError)")
				}

				return false
			}

			if let grpcError = error as? any GRPCStatusTransformable {
				return handleGrpcStatus(grpcError.makeGRPCStatus())
			} else if let grpcError = error as? GRPCStatus {
				return handleGrpcStatus(grpcError)
			} else {
				// Agent is not responding - could indicate VM issues
				self.logger.error("Agent monitoring: VM \(self.location.name) agent not responding: \(error)")  // Check if it's a permanent failure (connection refused, etc.)
			}
			
			return false
		}

		private func createCakeAgentHelper(connectionTimeout: Int64 = 5, retries: ConnectionBackoff.Retries = .upTo(1)) throws -> CakeAgentHelper {
			return try CakeAgentHelper.createCakeAgentHelper(location: self.location, connectionTimeout: connectionTimeout, retries: retries, runMode: self.runMode)
		}
	}

	private class AgentStatusWatcher: Cancellable {
		let location: VMLocation
		let statusStream: AsyncThrowingStreamCurrentStatusReplyYield
		let runMode: Utils.RunMode
		let stream: AsyncThrowingStreamCakedCurrentStatusReply
		let agentMonitor: CurrentStatusHandler.CurrentUsageWatcher
		let logger = Logger("AgentStatusWatcher")

		init(location: VMLocation, statusStream: AsyncThrowingStreamCurrentStatusReplyYield, runMode: Utils.RunMode) {
			let stream: AsyncThrowingStreamCakedCurrentStatusReply = AsyncThrowingStream<Caked_CurrentStatus, Error>.makeStream()
			let agentMonitor = CurrentStatusHandler.CurrentUsageWatcher(location: location, runMode: runMode, continuation: stream.continuation)

			self.location = location
			self.statusStream = statusStream
			self.runMode = runMode
			self.stream = stream
			self.agentMonitor = agentMonitor
		}
		
		func handler() async throws {
			try await withTaskCancellationHandler(operation: {
				try await withThrowingTaskGroup(of: Void.self) { group in
					var group = group

					let monitor = try FileMonitor(directory: self.location.rootURL, delegate: Watcher(location: self.location) { event in
						switch event {
						case .added(let file):
							check(file)
						case .deleted(let file):
							check(file)
						case .changed(let file):
							check(file)
						}
					})
					
					defer {
						monitor.stop()
						self.agentMonitor.cancel()
						group.cancelAll()
						self.stream.continuation.finish(throwing: CancellationError())
					}
					
					func check(_ file: URL) -> Void {
						let statusFiles = [self.location.pidFile.lastPathComponent, self.location.restartURL.lastPathComponent]

						if statusFiles.contains(file.lastPathComponent) {
							let status = self.location.status

							self.logger.debug("Status changed for VM \(self.location.name) to \(status)")

							switch status {
							case .running(let mode):
								self.stream.continuation.yield(.with {
									switch mode {
									case .none:
										$0.status = .error
									case .caked:
										$0.status = .running
									case .caker:
										$0.status = .running
									case .provision:
										$0.status = .provisioning
									case .restart:
										$0.status = .restarting
									}
								})
							case .stopped:
								// The stop half of a restart: the restart marker's removal reports the outcome.
								if self.location.restartURL.fileExists == false {
									self.stream.continuation.yield(.with {
										$0.status = .stopped
									})
								}
							default:
								self.stream.continuation.yield(.with {
									$0.status = .paused
								})
							}
						} else if file.lastPathComponent == self.location.screenshotURL.lastPathComponent {
							if let png = try? Data(contentsOf: self.location.screenshotURL) {
								self.statusStream.yield(.screenshot(png))
							}
						}
					}
					
					self.logger.debug("Start file monitor for \(self.location.name)")

					try monitor.start()
					
					if case .running = self.location.status {
						group.addTask {
							self.logger.debug("Start agent monitor for VM \(self.location.name)")
							await self.agentMonitor.start()
						}
					}
					
					group.addTask {
						try await withTaskCancellationHandler(operation: {
							for try await reply in self.stream.stream {
								switch reply.message {
								case .usage(let usage):
									self.statusStream.yield(.usage(usage))
								case .screenshot(let png):
									self.statusStream.yield(.screenshot(png))
								case .status(let status):
									self.logger.debug("Handle new status for VM \(self.location.name) to \(status)")
									self.statusStream.yield(.status(.init(status)))
									
									if status == .running && self.agentMonitor.isMonitoring == false {
										group.addTask {
											self.logger.debug("Start agent monitor for VM \(self.location.name)")
											await self.agentMonitor.start()
										}
									} else if status != .running && self.agentMonitor.isMonitoring {
										self.logger.debug("Stop agent monitor for VM \(self.location.name)")
										self.agentMonitor.cancel()
									}
								case .failure(let reason):
									self.logger.debug("Failure for VM \(self.location.name), \(reason)")
									self.statusStream.yield(.error(ServiceError(reason)))
								default:
									break
								}
							}
						}, onCancel: {
							self.logger.debug("Cancellation status watcher for VM \(self.location.name)")
							self.stream.continuation.finish(throwing: CancellationError())
						})
					}
					
					try await group.waitForAll()
				}
			}, onCancel: {
				self.logger.debug("General cancel status watcher for VM \(self.location.name)")
				self.agentMonitor.cancel()
				self.stream.continuation.finish(throwing: CancellationError())
			})
		}

		func run(frequency: Int32) -> Self {
			TaskQueue.dispatch {
				try await self.handler()
			}

			return self
		}

		func cancel() {
			self.agentMonitor.cancel()
			self.stream.continuation.finish(throwing: CancellationError())
		}
	}

	private class Watcher: FileDidChangeDelegate {
		let location: VMLocation
		let handler: (_ event: FileChangeEvent) -> Void

		init(location: VMLocation, handler: @escaping (_ event: FileChangeEvent) -> Void) {
			self.location = location
			self.handler = handler
		}

		func fileDidChanged(event: FileMonitorShared.FileChangeEvent) {
			handler(event)
		}
	}

	public enum CurrentStatusReply: Sendable {
		case usage(Caked_CurrentUsageReply)
		case error(Error)
		case status(VMLocation.Status)
		case screenshot(Data)
	}

	public static func currentStatus(vmURL: URL, frequency: Int32, statusStream: AsyncThrowingStreamCurrentStatusReplyYield, runMode: Utils.RunMode) async throws -> Cancellable {
		return try await currentStatus(location: VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode), frequency: frequency, statusStream: statusStream, runMode: runMode)
	}

	public static func currentStatus(location: VMLocation, frequency: Int32, statusStream: AsyncThrowingStreamCurrentStatusReplyYield, runMode: Utils.RunMode) async throws -> Cancellable {
		return AgentStatusWatcher(location: location, statusStream: statusStream, runMode: runMode).run(frequency: frequency)
	}

	public static func currentStatus(location: VMLocation, frequency: Int32, responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>, runMode: Utils.RunMode) async throws -> Cancellable {

		return TaskCancellable {
			let (stream, continuation) = AsyncThrowingStream<CurrentStatusReply, Error>.makeStream()
			let statusWatcher = try await Self.currentStatus(location: location, frequency: frequency, statusStream: continuation, runMode: runMode)

			try await withTaskCancellationHandler(operation: {
				for try await reply in stream {
					switch reply {
					case .usage(let usage):
						try await responseStream.send(.with {
							$0.status = .with {
								$0.statuses = [
									.with {
										$0.name = location.name
										$0.usage = usage
									}
								]
							}
						})
						
					case .error(let error):
						try await responseStream.send(.with {
							$0.status = .with {
								$0.statuses = [
									.with {
										$0.name = location.name
										$0.failure = error.reason
									}
								]
							}
						})
						
					case .status(let status):
						try await responseStream.send(.with {
							$0.status = .with {
								$0.statuses = [
									.with {
										$0.name = location.name
										$0.status = .init(status)
									}
								]
							}
						})
						
					case .screenshot(let png):
						try await responseStream.send(.with {
							$0.status = .with {
								$0.statuses = [
									.with {
										$0.name = location.name
										$0.screenshot = png
									}
								]
							}
						})
					}
				}
			}, onCancel: {
				continuation.finish(throwing: CancellationError())
				statusWatcher.cancel()
			})
		}
	}

	public static func currentStatus(vmname: String, frequency: Int32, responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>, runMode: Utils.RunMode) async throws -> Cancellable {
		try await currentStatus(location: try StorageLocation(runMode: runMode).find(vmname), frequency: frequency, responseStream: responseStream, runMode: runMode)
	}
	
	public static func currentStatus(responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>, vmname: String, frequency: Int32, runMode: Utils.RunMode) async throws -> Cancellable {
		try await self.currentStatus(vmname: vmname, frequency: frequency, responseStream: responseStream, runMode: runMode)
	}
}

