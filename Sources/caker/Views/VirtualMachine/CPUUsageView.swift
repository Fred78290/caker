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

let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .brown, .gray]

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

	private func memGraph(memoryInfos: MemoryInfo) -> some View {
		GeometryReader { proxy in
			HStack(alignment: .top, spacing: max(1, proxy.size.width / 120)) {
				let height = memoryInfos.total != 0 ? (proxy.size.height - 2) * CGFloat(memoryInfos.used) / CGFloat(memoryInfos.total) : 0
				
				Rectangle()
					.fill(.gray.opacity(0.4))
					.frame(width: 8, height: proxy.size.height)
					.border(.black.opacity(0.8), width: 1)
					.overlay {
						Rectangle()
							.fill(.green)
							.frame(width: 6, height: height)
							.offset(x: 0, y: ((proxy.size.height - height) / 2) - 1)
							.animation(Animation.easeInOut(duration: 0.1), value: height)
					}
			}.padding(0)

		}
	}

	private func cpuGraph(cores: [CoreInfo]) -> some View {
		GeometryReader { proxy in
			HStack(alignment: .top, spacing: max(1, proxy.size.width / 120)) {
				ForEach(Array(cores.enumerated()), id: \.offset) { index, core in
					let height = ((proxy.size.height - 2) * core.usagePercent) / 100

					Rectangle()
						.fill(.gray.opacity(0.4))
						.frame(width: 8, height: proxy.size.height)
						.border(.black.opacity(0.8), width: 1)
						.overlay {
							Rectangle()
								.fill(.green)
								.frame(width: 6, height: height)
								.offset(x:0, y: ((proxy.size.height - height) / 2) - 1)
								.animation(Animation.easeInOut(duration: 0.1), value: height)
						}//.log(text: "core: proxy.size.height=\(proxy.size.height) height=\(height), core.usagePercent=\(core.usagePercent), offsetY: \(proxy.size.height - height)")

				}
			}
			//.background(.red.opacity(0.4))
			.padding(0)
			//.log(text: "cpuGraph: \(proxy.size.height)")
		}
	}

	var body: some View {
		HStack {
			let cores = (monitoringTask != nil) ? monitoringTask!.cpuInfos.cores : []
			let memoryInfos = monitoringTask?.memoryInfos

			if cores.isEmpty {
				if let firstIP = self.firstIP {
					HStack(spacing: 2) {
						Image(systemName: "network")
							.foregroundColor(.secondary)
							.font(.subheadline)
						Text(firstIP)
							.foregroundColor(.secondary)
							.font(.subheadline)
					}.help("CPU usage unavailable")
				} else {
					EmptyView()
						.padding(.horizontal, 6)
						.padding(.vertical, 4)
						.help("CPU usage unavailable")
				}
			} else {
				HStack(alignment: .center, spacing: 2) {
					if let firstIP = firstIP {
						Image(systemName: "network")
							.foregroundColor(.secondary)
							.font(.subheadline)
						Text(firstIP)
							.foregroundColor(.secondary)
							.font(.subheadline)
					}
					
					// Vertical bars for each CPU core
					Image(systemName: "cpu")
						.foregroundColor(.secondary)
						.font(.subheadline)
					
					cpuGraph(cores: cores)
						.frame(width: CGFloat(cores.count * 10), height: 20)
					
					if let memoryInfos = memoryInfos {
						Image(systemName: "memorychip")
							.foregroundColor(.secondary)
							.font(.subheadline)
						
						memGraph(memoryInfos: memoryInfos)
							.frame(width: 8, height: 20)
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
}

