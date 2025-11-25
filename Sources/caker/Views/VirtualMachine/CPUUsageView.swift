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

struct CPUUsageView: View {
	let vmInfos: VMInformations

	var body: some View {
		Group {
			if let cpuInfos = vmInfos.cpuInfos {
				HStack(spacing: 2) {
					if let firstIP = vmInfos.ipaddresses.first {
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
						ForEach(Array(cpuInfos.cores.enumerated()), id: \.offset) { index, core in
							VStack(spacing: 0) {
								Spacer()

								Rectangle()
									.frame(width: 8, height: max(2, core.usagePercent / 100.0 * 16))
									.foregroundColor(cpuUsageColor(core.usagePercent))

								Rectangle()
									.frame(width: 8, height: max(0, 16 - (core.usagePercent / 100.0 * 16)))
									.foregroundColor(Color.clear)
							}
							.frame(height: 16)
							.help("Core \(index): \(Int(core.usagePercent))%\nUser: \(String(format: "%.1f", core.user))%\nSystem: \(String(format: "%.1f", core.system))%\nIdle: \(String(format: "%.1f", core.idle))%")
						}
					}
				}
				.padding(.horizontal, 6)
				.padding(.vertical, 4)
				.background(Color.secondary.opacity(0.1))
				.cornerRadius(4)
				.help("CPU Cores Usage (\(cpuInfos.cores.count) cores total)")
			} else {
				EmptyView()
					.padding(.horizontal, 6)
					.padding(.vertical, 4)
					.help("CPU usage unavailable")
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
