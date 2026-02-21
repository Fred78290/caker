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

typealias AsyncThrowingStreamCakeAgentCurrentUsageReply = (
	stream: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>,
	continuation: AsyncThrowingStream<CakeAgent.CurrentUsageReply, Error>.Continuation
)

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
		private let location: VMLocation
		private var isMonitoring: Bool = false
		private var stream: AsyncThrowingStreamCakeAgentCurrentUsageReply? = nil
		private let continuation: AsyncThrowingStream<Caked_CurrentStatusReply, Error>.Continuation

#if DEBUG
		private let logger = Logger("CPUUsageMonitor")
#endif

		init(location: VMLocation, continuation: AsyncThrowingStream<Caked_CurrentStatusReply, Error>.Continuation) {
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

			#if DEBUG
			self.logger.debug("Cancel monitoring current CPU usage, VM: \(self.location.name), \(_file):\(_line)")
			#endif

			if let stream {
				stream.continuation.finish(throwing: GRPCStatus(code: .cancelled, message: "Cancelled"))
			}
		}

		private func handleAgentHealthCurrentUsage(usage: CakeAgent.CurrentUsageReply) {
			self.continuation.yield(.with {
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

			#if DEBUG
			let debugLogger = self.logger

			debugLogger.debug("Start monitoring current CPU usage, VM: \(self.location.name)")
			#endif

			await withTaskCancellationHandler(operation: {
				let taskQueue = TaskQueue(label: "CakeAgent.CPUUsageMonitor.\(self.location.name)")
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

				while Task.isCancelled == false && self.isMonitoring {
					do {
						helper = try self.createHelper()

						self.stream = performAgentHealthCheck()

						for try await currentUsage in stream!.stream {
							handleAgentHealthCurrentUsage(usage: currentUsage)
						}
						
						break
					} catch {
						if self.isMonitoring {
							try? await helper?.close().get()

							self.stream = nil

							guard self.handleAgentHealthCheckFailure(error: error) else {
								return
							}
							#if DEBUG
							debugLogger.debug("Monitoring agent not ready, VM: \(self.location.name), waiting...")
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
				debugLogger.debug("Monitoring ended, VM: \(self.location.name)")
	#endif
			}, onCancel: {
			#if DEBUG
				debugLogger.debug("Monitoring canceled, VM: \(self.location.name)")
			#endif
				self.stream?.continuation.finish()
			})
		}

		private func handleAgentHealthCheckFailure(error: Error) -> Bool {
	#if DEBUG
			self.logger.debug("Agent monitoring: VM \(self.location.name) is not ready")
	#endif

			func handleGrpcStatus(_ grpcError: GRPCStatus) -> Bool {
				switch grpcError.code {
				case .unavailable:
					// These could be temporary - continue monitoring
					self.logger.info("Agent monitoring: VM \(self.location.name) agent unvailable")
					return true
				case .cancelled:
					// These could be temporary - continue monitoring
					self.logger.info("Agent monitoring: VM \(self.location.name) agent cancelled")
				case .deadlineExceeded:
					// Timeout - VM might be under heavy load
					self.logger.info("Agent monitoring: VM \(self.location.name) agent timeout")
					return true
				case .unimplemented:
					// unimplemented - Agent is too old, need update
					self.logger.info("Agent monitoring: VM \(self.location.name) agent is too old, need update")
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

	public static func currentStatus(rootURL: URL, frequency: Int32, statusStream: AsyncThrowingStreamCurrentStatusReplyYield, runMode: Utils.RunMode) async throws {
		try await currentStatus(location: VMLocation.newVMLocation(rootURL: rootURL), frequency: frequency, statusStream: statusStream, runMode: runMode)
	}

	public static func currentStatus(location: VMLocation, frequency: Int32, statusStream: AsyncThrowingStreamCurrentStatusReplyYield, runMode: Utils.RunMode) async throws {
		var lastStatusSeen = location.status
		let (stream, continuation) = AsyncThrowingStream<Caked_CurrentStatusReply, Error>.makeStream()
		let agentMonitor = Self.CurrentUsageWatcher(location: location, continuation: continuation)

		try await withThrowingTaskGroup(of: Void.self) { group in
			var group = group
			let monitor = try FileMonitor(directory: location.rootURL, delegate: Watcher(location: location) { event in
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
				agentMonitor.cancel()
				group.cancelAll()
			}

			func check(_ file: URL) -> Void {
				if file.lastPathComponent == location.pidFile.lastPathComponent {
					let status = location.status

					switch status {
					case .running:
						statusStream.yield(.status(.running))
					case .stopped:
						statusStream.yield(.status(.stopped))
					default:
						statusStream.yield(.status(.paused))
					}

					if status == .running && lastStatusSeen == .stopped {
						group.addTask {
							await agentMonitor.start()
						}
					} else if status != .running && lastStatusSeen == .running {
						agentMonitor.cancel()
					}

					lastStatusSeen = status
				} else if file.lastPathComponent == location.screenshotURL.lastPathComponent {
					if let png = try? Data(contentsOf: location.screenshotURL) {
						statusStream.yield(.screenshot(png))
					}
				}
			}

			try monitor.start()

			if location.status == .running {
				group.addTask {
					await agentMonitor.start()
				}
			}

			try await withTaskCancellationHandler(operation: {
				for try await reply in stream {
					statusStream.yield(.usage(reply.usage))
				}
			}, onCancel: {
				continuation.finish(throwing: CancellationError())
			})
		}
	}

	public static func currentStatus(location: VMLocation, frequency: Int32, responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>, runMode: Utils.RunMode) async throws {

		try await withThrowingTaskGroup(of: Void.self) { group in
			let (stream, continuation) = AsyncThrowingStream<CurrentStatusReply, Error>.makeStream()

			group.addTask {
				try await Self.currentStatus(location: location, frequency: frequency, statusStream: continuation, runMode: runMode)
			}

			try await withTaskCancellationHandler(operation: {
				for try await reply in stream {
					switch reply {
					case .usage(let usage):
						try await responseStream.send(.with {
							$0.status = .with {
								$0.usage = usage
							}
						})

					case .error(let error):
						try await responseStream.send(.with {
							$0.status = .with {
								$0.failure = "\(error)"
							}
						})

					case .status(let status):
						try await responseStream.send(.with {
							$0.status = .with {
								$0.status = .init(from:  status)
							}
						})

					case .screenshot(let png):
						try await responseStream.send(.with {
							$0.status = .with {
								$0.screenshot = png
							}
						})
					}
				}
			}, onCancel: {
				continuation.finish(throwing: CancellationError())
			})
		}
	}

	public static func currentStatus(vmname: String, frequency: Int32, responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>, runMode: Utils.RunMode) async throws {
		try await currentStatus(location: try StorageLocation(runMode: runMode).find(vmname), frequency: frequency, responseStream: responseStream, runMode: runMode)
	}
	
	public static func currentStatus(responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>, vmname: String, frequency: Int32, runMode: Utils.RunMode) async throws {
		try await self.currentStatus(vmname: vmname, frequency: frequency, responseStream: responseStream, runMode: runMode)
	}
}

