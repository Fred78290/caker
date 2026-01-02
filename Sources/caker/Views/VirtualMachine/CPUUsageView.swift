//
//  CPUUsageView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/11/2025.
//

import CakeAgentLib
import CakedLib
import GRPCLib
import SwiftUI
import SwiftletUtilities

struct CPUUsageView: View {
	@Binding private var vmInfos: VirtualMachineInformations
	private var oldCpuInfos: CpuInfos? = nil

	init(vmInfos: Binding<VirtualMachineInformations>) {
		self._vmInfos = vmInfos
		self.oldCpuInfos = vmInfos.wrappedValue.cpuInfos
	}

	var body: some View {
		Group {
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
						}.foregroundColor(Color.systemGray)
					}
				}
				.padding(.horizontal, 6)
				.padding(.vertical, 4)
				.help("CPU Cores Usage (\(cpuInfos.cores.count) cores total)")
			}
		}
	}

	private func cpuUsageColor(_ usage: Double) -> Color {
		switch usage {
		case 0..<30:
			return .green
		case 30..<70:
			return .yellow
		case 70..<90:
			return .orange
		default:
			return .red
		}
	}
}
