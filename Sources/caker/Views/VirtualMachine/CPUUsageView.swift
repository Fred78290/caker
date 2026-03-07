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
	private static let barColor = Color(fromHex: "0076fFFF")!

	private static var borderColor:Color {
		switch Color.colorScheme {
		case .dark:
			return .white
		default:
			return .black
		}
	}

	private static var bgColor:Color {
		switch Color.colorScheme {
		case .dark:
			return Color(fromHex: "C7C7CCFF")!
		default:
			return Color(fromHex: "636366FF")!
		}
	}

	@Binding var cpuInfos: CpuInfos
	@Binding var memoryInfos: MemoryInfo
	private let firstIP: String?
	private let cancel: () -> Void
	private let start: () async -> Void

#if DEBUG
		private let logger = Logger("CPUUsageView")
	#endif

	init(firstIP: String?, cpuInfos: Binding<CpuInfos>, memoryInfos: Binding<MemoryInfo>, cancel: @escaping () -> Void, start: @escaping () async -> Void) {
		self.firstIP = firstIP
		self._cpuInfos = cpuInfos
		self._memoryInfos = memoryInfos
		self.cancel = cancel
		self.start = start
	}

	private func bar(height: CGFloat) -> some View {
		GeometryReader { proxy in
			Rectangle()
				.fill(Self.bgColor.opacity(0.4))
				.frame(width: proxy.size.width, height: proxy.size.height)
				.border(Self.borderColor.opacity(0.6), width: 0.5)
				.overlay {
					Rectangle()
						.fill(Self.barColor)
						.frame(width: proxy.size.width - 2, height: height)
						.offset(x: 0, y: ((proxy.size.height - height) / 2) - 1)
						.animation(Animation.easeInOut(duration: 0.1), value: height)
				}
		}
	}

	private func memGraph(memoryInfos: MemoryInfo) -> some View {
		GeometryReader { proxy in
			HStack(alignment: .top, spacing: max(1, proxy.size.width / 120)) {
				let height = memoryInfos.total != 0 ? (proxy.size.height - 1) * CGFloat(memoryInfos.used) / CGFloat(memoryInfos.total) : 0
				
				self.bar(height: height).frame(width: 8, height: proxy.size.height)
			}.padding(0)

		}
	}

	private func cpuGraph(cores: [CoreInfo]) -> some View {
		GeometryReader { proxy in
			HStack(alignment: .top, spacing: max(1, proxy.size.width / 120)) {
				ForEach(Array(cores.enumerated()), id: \.offset) { index, core in
					let height = ((proxy.size.height - 1) * core.usagePercent) / 100

					self.bar(height: height).frame(width: 8, height: proxy.size.height)
				}
			}
			.padding(0)
		}
	}

	var body: some View {
		let cores = self.cpuInfos.cores
		let memoryInfos = self.memoryInfos

		HStack(alignment: .center, spacing: 6) {
			if cores.isEmpty {
				if let firstIP = self.firstIP {
					HStack(alignment: .center, spacing: 2) {
						Image(systemName: "network")
							.foregroundColor(.secondary)
							.font(.title2)
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
				if let firstIP = self.firstIP {
					HStack(alignment: .center, spacing: 2) {
						Image(systemName: "network")
							.foregroundColor(.secondary)
							.font(.title2)
						Text(firstIP)
							.foregroundColor(.secondary)
							.font(.subheadline)
					}
				}
				
				// Vertical bars for each CPU core
				HStack(alignment: .center, spacing: 2) {
					Image(systemName: "cpu")
						.foregroundColor(.secondary)
						.font(.title2)
					
					cpuGraph(cores: cores)
						.frame(width: CGFloat(cores.count * 10), height: 20)
				}

				HStack(alignment: .center, spacing: 2) {
					Image(systemName: "memorychip")
						.foregroundColor(.secondary)
						.font(.title2)
					
					memGraph(memoryInfos: memoryInfos)
						.frame(width: 8, height: 20)
				}
			}
		}
		.padding(.horizontal, 8)
		.padding(.vertical, 4)
		.help("CPU Cores Usage (\(cores.count) cores total)")
		.task {
			// Cancel any existing monitoring task before starting a new one
			self.cancel()
			await self.start()
		}
		.onDisappear {
			// Cancel monitoring when the view disappears
			self.cancel()
		}
	}
}

