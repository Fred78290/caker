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

struct CPUUsageView: View {
	let name: String

	@StateObject private var vmInfos = VirtualMachineInformations()
	#if DEBUG
		private let logger = Logger("CPUUsageView")
	#endif

	var body: some View {
		HStack {
			if vmInfos.cpuInfos.cores.isEmpty {
				EmptyView()
					.padding(.horizontal, 6)
					.padding(.vertical, 4)
					.help("CPU usage unavailable")
			} else {
				let cpuInfos = vmInfos.cpuInfos

				HStack(spacing: 2) {
					if let firstIP = vmInfos.ipaddresses?.first {
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
							ForEach(Array(cpuInfos.cores.enumerated()), id: \.offset) { index, core in
								let height = proxy.size.height * core.usagePercent / 100
								
								Rectangle()
									.fill(Color.accentColor)
									.frame(height: height)
									.offset(x: 0, y: proxy.size.height - height)
									.animation(Animation.easeInOut(duration: 0.1), value: height)
							}
						}
						.foregroundColor(Color.systemGray)
						.frame(width: CGFloat(cpuInfos.cores.count * 8))
					}
				}
				.padding(.horizontal, 6)
				.padding(.vertical, 4)
				.help("CPU Cores Usage (\(cpuInfos.cores.count) cores total)")
				.log("CPUUsageView", text: "Update")
			}
		}.task {
			await monitorCurrentUsage()
		}
	}

	func monitorCurrentUsage() async {
		let stream = AsyncStream.makeStream(of: CakeAgent.CurrentUsageReply.self)

		await withTaskCancellationHandler(operation: {
			var isWaitingForAgent: Bool = true

			while Task.isCancelled == false && isWaitingForAgent {
				isWaitingForAgent = await self.performAgentHealthCheck(stream: stream)

				if isWaitingForAgent {
					try? await Task.sleep(nanoseconds: 1_000_000_000)
				}
			}
		}, onCancel: {
			stream.continuation.finish()
		})
	}

	static func createHelper(name: String) throws -> CakeAgentHelper {
		let eventLoop = Utilities.group.next()
		let client = try Utilities.createCakeAgentClient(
			on: eventLoop,
			runMode: .app,
			name: name,
			connectionTimeout: 5,
			retries: .upTo(1)
		)

		return CakeAgentHelper(on: eventLoop, client: client)
	}

	@MainActor
	private func handleAgentHealthCurrentUsage(usage: CakeAgent.CurrentUsageReply) {
		self.vmInfos.update(from: usage)
	}

	@MainActor
	private func handleAgentHealthCheckSuccess(info: InfoReply) {
		// Agent is responding - optionally update VM info if needed
		// For example, you could update IP addresses or system info
		#if DEBUG
			self.logger.debug("Agent monitoring: VM \(self.name) is healthy, uptime: \(info.uptime ?? 0)s")
		#endif

		self.vmInfos.update(from: info)

		// Update IP addresses if they changed
		#if DEBUG
			if let firstIP = info.ipaddresses.first {
				self.logger.debug("VM \(self.name) current IP address: \(firstIP)")
			}
		#endif
	}

	private func handleAgentHealthCheckFailure(error: Error, continueMonitoring: Bool) -> Bool {
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
			let callOptions = CallOptions(timeLimit: .timeout(.seconds(10)))
			let helper = try Self.createHelper(name: self.name)

			defer {
				try? helper.closeSync()
			}

			self.handleAgentHealthCheckSuccess(info: try helper.info(callOptions: callOptions))

			try helper.currentUsage(frequency: 20, callOptions: CallOptions(timeLimit: .none), continuation: stream.continuation)

			continueMonitoring = false

			for try await currentUsage in stream.stream {
				self.handleAgentHealthCurrentUsage(usage: currentUsage)
			}

		} catch {
			return handleAgentHealthCheckFailure(error: error, continueMonitoring: continueMonitoring)
		}

		return false
	}
}
