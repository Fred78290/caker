//
//  CPUUsageView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/11/2025.
//

import CakeAgentLib
import CakedLib
import GRPC
import GRPCLib
import SwiftUI
import SwiftletUtilities
import NIO

struct CPUUsageView: View {
	private let name: String
	private let firstIP: String?
	private let eventLoop: EventLoop

	//@State private var cpuInfos = CpuInfos()
	@State private var monitoringTask: CPUUsageMonitor? = nil
	#if DEBUG
		private let logger = Logger("CPUUsageView")
	#endif

	init(name: String, firstIP: String?) {
		self.name = name
		self.firstIP = firstIP
		self.eventLoop = Utilities.group.next()
	}

	var body: some View {
		HStack {
			let cores = (monitoringTask != nil) ? monitoringTask!.cpuInfos.cores : []

			if cores.isEmpty {
				if let firstIP = self.firstIP {
					HStack(spacing: 2) {
						Image(systemName: "network")
							.foregroundColor(.secondary)
							.font(.caption)
						Text(firstIP)
							.foregroundColor(.secondary)
							.font(.caption)
					}.help("CPU usage unavailable")
				} else {
					EmptyView()
						.padding(.horizontal, 6)
						.padding(.vertical, 4)
						.help("CPU usage unavailable")
				}
			} else {
				HStack(spacing: 2) {
					if let firstIP = firstIP {
						Image(systemName: "network")
							.foregroundColor(.secondary)
							.font(.caption)
						Text(firstIP)
							.foregroundColor(.secondary)
							.font(.caption)
					}
					Image(systemName: "cpu")
						.foregroundColor(.secondary)
						.font(.caption)

					// Vertical bars for each CPU core
					HStack(spacing: 1) {
						GeometryReader { proxy in
							ForEach(Array(cores.enumerated()), id: \.offset) { index, core in
								let height = proxy.size.height * core.usagePercent / 100
								
								Rectangle()
									.fill(Color.accentColor)
									.frame(height: height)
									.offset(x: 0, y: proxy.size.height - height)
									.animation(Animation.easeInOut(duration: 0.1), value: height)
							}
						}
						.foregroundColor(Color.systemGray)
						.frame(width: CGFloat(cores.count * 8))
					}
				}
				.padding(.horizontal, 6)
				.padding(.vertical, 4)
				.help("CPU Cores Usage (\(cores.count) cores total)")
			}
		}
		.task {
			// Cancel any existing monitoring task before starting a new one
			monitoringTask?.cancel()
			monitoringTask = CPUUsageMonitor(name: self.name)
			await monitoringTask?.monitorCurrentUsage()
		}
		.onDisappear {
			// Cancel monitoring when the view disappears
			monitoringTask?.cancel()
			monitoringTask = nil
		}
	}

	func monitorCurrentUsage() async {
		#if DEBUG
		let debugLogger = self.logger

		debugLogger.debug("Start monitoring current CPU usage, VM: \(self.name)")
		#endif

		let stream = AsyncStream.makeStream(of: CakeAgent.CurrentUsageReply.self)

		await withTaskCancellationHandler(operation: {
			var isWaitingForAgent: Bool = true

			while Task.isCancelled == false && isWaitingForAgent {
				isWaitingForAgent = await self.performAgentHealthCheck(stream: stream)

				if isWaitingForAgent {
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
			stream.continuation.finish()
		})
	}

	func createHelper() throws -> CakeAgentHelper {
		let client = try Utilities.createCakeAgentClient(
			on: self.eventLoop,
			runMode: .app,
			name: name,
			connectionTimeout: 5,
			retries: .upTo(1)
		)

		return CakeAgentHelper(on: self.eventLoop.next(), client: client)
	}

	@MainActor
	private func handleAgentHealthCurrentUsage(usage: CakeAgent.CurrentUsageReply) {
		//self.cpuInfos.update(from: usage.cpuInfos)
	}

	private func handleAgentHealthCheckFailure(error: Error, continueMonitoring: Bool) -> Bool {
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
		
		return continueMonitoring
	}

	private func performAgentHealthCheck(stream: (stream: AsyncStream<CakeAgent.CurrentUsageReply>, continuation: AsyncStream<CakeAgent.CurrentUsageReply>.Continuation)) async -> Bool {
		var continueMonitoring = true

		do {
			let helper = try self.createHelper()

			defer {
				try? helper.closeSync()
			}

			try helper.currentUsage(frequency: 1, callOptions: CallOptions(timeLimit: .none), continuation: stream.continuation)

#if DEBUG
			self.logger.debug("Agent monitoring: VM \(self.name) is ready")
#endif

			continueMonitoring = false

			for try await currentUsage in stream.stream {
				self.handleAgentHealthCurrentUsage(usage: currentUsage)
			}

			#if DEBUG
				self.logger.debug("Exit agent monitoring: VM \(self.name)")
			#endif
		} catch {
			return handleAgentHealthCheckFailure(error: error, continueMonitoring: continueMonitoring)
		}

		return false
	}
}

