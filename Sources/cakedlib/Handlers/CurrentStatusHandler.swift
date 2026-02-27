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

typealias AsyncThrowingStreamCakedCurrentStatusReply = (
	stream: AsyncThrowingStream<Caked_CurrentStatus, Error>,
	continuation: AsyncThrowingStream<Caked_CurrentStatus, Error>.Continuation
)

typealias AsyncThrowingStreamCakeAgentCurrentUsageReply = (
	stream: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>,
	continuation: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>.Continuation
)

public extension VMLocation.Status {
	init(from: Caked_VirtualMachineStatus) {
		switch from {
		case .stopped:
			self = .stopped
		case .running:
			self = .running
		case .paused:
			self = .paused
		default:
			self = .stopped
		}
	}
}

public extension Caked_VirtualMachineStatus {
	init(from: VMLocation.Status) {
		switch from {
		case .running:
			self = .running
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
		internal var isMonitoring: Bool = false
		private let location: VMLocation
		private var stream: AsyncThrowingStreamCakeAgentCurrentUsageReply? = nil
		private let continuation: AsyncThrowingStream<Caked_CurrentStatus, Error>.Continuation
		private let logger = Logger("CurrentUsageWatcher")

		init(location: VMLocation, continuation: AsyncThrowingStream<Caked_CurrentStatus, Error>.Continuation) {
			self.location = location
			self.continuation = continuation
		}

		func start() async {
			await monitorCurrentUsage()
		}

		func cancel(_line: UInt = #line, _file: String = #file) {
			guard self.isMonitoring else {
				return
			}

			self.isMonitoring = false
			self.logger.debug("Cancel monitoring current CPU usage, VM: \(self.location.name), \(_file):\(_line)")

			if let stream {
				stream.continuation.finish(throwing: CancellationError())
			}
		}

		private func handleAgentHealthCurrentUsage(usage: CakeAgent.CurrentUsageReply) {
			self.continuation.yield(.with {
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
						}
					}
				}
			})
		}

		private func handleAgentHealthCurrentUsage(usage: InfoReply) {
			let usage = usage.caked

			self.continuation.yield(.with {
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
			})
		}

		func monitorCurrentUsage() async {
			guard self.isMonitoring == false else {
				return
			}

			self.logger.debug("Start monitoring current CPU usage, VM: \(self.location.name)")

			await withTaskCancellationHandler(operation: {
				let taskQueue = TaskQueue(label: "CakeAgent.CurrentUsageWatcher.\(self.location.name)")
				var helper: CakeAgentHelper! = nil

				self.isMonitoring = true

				func performAgentHealthCheck() -> AsyncThrowingStreamCakeAgentCurrentUsageReply {
					return taskQueue.dispatchStream { [weak self] (continuation: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>.Continuation) in
						guard let self = self else {
							return
						}

						do {
							let infos = try helper.info(callOptions: CallOptions(timeLimit: .timeout(.seconds(10))))

							self.handleAgentHealthCurrentUsage(usage: infos)

							helper.currentUsage(frequency: 1, callOptions: CallOptions(timeLimit: .none), continuation: continuation)
						} catch {
							continuation.finish(throwing: error)
						}
					}
				}

				func close() {
					
				}

				while Task.isCancelled == false && self.isMonitoring {
					do {
						helper = try self.createHelper()
						
						self.stream = performAgentHealthCheck()
						
						for try await currentUsage in stream!.stream {
							handleAgentHealthCurrentUsage(usage: currentUsage)
						}
						
						break
					} catch is CancellationError {
						self.isMonitoring = false
					} catch {
						if self.isMonitoring {
							try? await helper?.close().get()

							self.stream = nil

							guard self.handleAgentHealthCheckFailure(error: error) else {
								return
							}
							self.logger.debug("Monitoring agent not ready, VM: \(self.location.name), waiting...")
							try? await Task.sleep(nanoseconds: 1_000_000_000)
						}
					}
				}

				taskQueue.close()
				try? await helper?.close().get()

				self.isMonitoring = false
				self.stream = nil

				self.logger.debug("Monitoring ended, VM: \(self.location.name)")
			}, onCancel: {
				self.logger.debug("Monitoring canceled, VM: \(self.location.name)")
				self.stream?.continuation.finish(throwing: CancellationError())
			})
		}

		private func handleAgentHealthCheckFailure(error: Error) -> Bool {
			self.logger.debug("Agent monitoring: VM \(self.location.name) is not ready")

			func handleGrpcStatus(_ grpcError: GRPCStatus) -> Bool {
				switch grpcError.code {
				case .unavailable:
					// These could be temporary - continue monitoring
					self.logger.debug("Agent monitoring: VM \(self.location.name) agent unvailable")
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

		private func createHelper(connectionTimeout: Int64 = 5) throws -> CakeAgentHelper {
			let eventLoop = Utilities.group.next()

			let client = try Utilities.createCakeAgentClient(
				on: eventLoop.next(),
				runMode: .app,
				listeningAddress: self.location.agentURL,
				connectionTimeout: connectionTimeout,
				retries: .upTo(1)
			)

			return CakeAgentHelper(on: eventLoop, client: client)
		}
	}

	private class AgentStatusWatcher: Cancellable {
		let location: VMLocation
		let statusStream: AsyncThrowingStreamCurrentStatusReplyYield
		let runMode: Utils.RunMode
		let stream: AsyncThrowingStreamCakedCurrentStatusReply
		let agentMonitor: CurrentStatusHandler.CurrentUsageWatcher

		init(location: VMLocation, statusStream: AsyncThrowingStreamCurrentStatusReplyYield, runMode: Utils.RunMode) {
			let stream: AsyncThrowingStreamCakedCurrentStatusReply = AsyncThrowingStream<Caked_CurrentStatus, Error>.makeStream()
			let agentMonitor = CurrentStatusHandler.CurrentUsageWatcher(location: location, continuation: stream.continuation)

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
						if file.lastPathComponent == self.location.pidFile.lastPathComponent {
							switch self.location.status {
							case .running:
								self.stream.continuation.yield(.with {
									$0.status = .running
								})
							case .stopped:
								self.stream.continuation.yield(.with {
									$0.status = .stopped
								})
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
					
					try monitor.start()
					
					if self.location.status == .running {
						group.addTask {
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
									self.statusStream.yield(.status(.init(from: status)))
									
									if status == .running && self.agentMonitor.isMonitoring == false {
										group.addTask {
											await self.agentMonitor.start()
										}
									} else if status != .running && self.agentMonitor.isMonitoring {
										self.agentMonitor.cancel()
									}
								case .failure(let reason):
									self.statusStream.yield(.error(ServiceError(reason)))
								default:
									break
								}
							}
						}, onCancel: {
							self.stream.continuation.finish(throwing: CancellationError())
						})
					}
					
					try await group.waitForAll()
				}
			}, onCancel: {
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

	public static func currentStatus(rootURL: URL, frequency: Int32, statusStream: AsyncThrowingStreamCurrentStatusReplyYield, runMode: Utils.RunMode) async throws -> Cancellable {
		return try await currentStatus(location: VMLocation.newVMLocation(rootURL: rootURL), frequency: frequency, statusStream: statusStream, runMode: runMode)
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
										$0.failure = "\(error)"
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
										$0.status = .init(from:  status)
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

