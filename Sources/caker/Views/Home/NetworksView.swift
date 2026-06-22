//
//  NetworksView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import GRPCLib
import SwiftUI

extension BridgedNetwork {
	var icon: Image {
		switch self.mode {
		case .bridged:
			if self.description.contains("Wi-Fi") {
				return Image(systemName: "wifi")
			} else if self.description.contains("Thunderbold") {
				return Image(systemName: "bolt")
			} else {
				return Image("ethernet").renderingMode(.template)
			}
		case .host:
			return Image(systemName: "network.badge.shield.half.filled")
		case .nat:
			return Image(systemName: "network")
		case .shared:
			return Image(systemName: "link")
		}
	}
}

struct NetworksView: View {
	@Bindable var navigationModel: NavigationModel
	@State private var selection: BridgedNetwork.ID? = nil
	@State private var disabled: Bool = false

	private func iconColor(for mode: BridgedNetworkMode) -> Color {
		switch mode {
		case .bridged: return .blue
		case .host: return .green
		case .nat: return .orange
		case .shared: return .purple
		}
	}

	var body: some View {
		GeometryReader { geom in
			if AppState.shared.networks.isEmpty {
				VStack(alignment: .center) {
					ContentUnavailableView("List empty", systemImage: "tray")
				}.frame(width: geom.size.width)
			} else {
				List(AppState.shared.networks, id: \.self, selection: $navigationModel.selectedNetwork) { network in
					HStack(spacing: 12) {
						ZStack {
							RoundedRectangle(cornerRadius: 9)
								.fill(iconColor(for: network.mode).gradient)
								.frame(width: 38, height: 38)
							network.icon
								.resizable()
								.aspectRatio(contentMode: .fit)
								.foregroundStyle(.white)
								.frame(width: 20, height: 20)
						}

						VStack(alignment: .leading, spacing: 2) {
							Text(network.name)
								.font(.system(size: 13, weight: .semibold))
							Text(network.description)
								.font(.system(size: 11))
								.foregroundStyle(.secondary)
						}

						Spacer()

						GlossyCircle(color: network.endpoint.isEmpty ? .red : .green)
							.frame(width: 12, height: 12)
					}
					.padding(.vertical, 4)
				}
				.listStyle(.inset(alternatesRowBackgrounds: true))
				.frame(size: geom.size)
			}
		}
	}
}

#Preview {
	NetworksView(navigationModel: .init(selectedCategory: .networks))
}
