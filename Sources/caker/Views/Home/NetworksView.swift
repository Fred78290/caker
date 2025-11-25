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
	@Environment(\.colorScheme) var colorScheme: ColorScheme
	@Binding var appState: AppState
	@Binding var navigationModel: NavigationModel
	@State private var selection: BridgedNetwork.ID? = nil
	@State private var disabled: Bool = false

	var body: some View {
		GeometryReader { geom in
			if appState.networks.isEmpty {
				if #available(macOS 14, *) {
					VStack(alignment: .center) {
						ContentUnavailableView("List empty", systemImage: "tray")
					}.frame(width: geom.size.width)
				} else {
					VStack(alignment: .center) {
						Image(systemName: "tray").resizable().scaledToFit().frame(width: 48, height: 48).foregroundStyle(.gray)
						Text("List empty").font(.largeTitle).fontWeight(.bold).foregroundStyle(.gray).multilineTextAlignment(.center)
					}.frame(width: geom.size.width)
				}
			} else {
				List(appState.networks, id: \.self, selection: $navigationModel.selectedNetwork) { network in
					GeometryReader { geom in
						HStack {
							network.icon
								.resizable()
								.aspectRatio(contentMode: .fit)
								.foregroundStyle(self.colorScheme == .dark ? .white : .primary)
								.frame(size: CGSize(width: geom.size.height, height: geom.size.height))

							Text("\(network.name)")
								.font(.headline)
								.frame(width: 60, alignment: .leading)

							Text("\(network.description)")
								.font(.headline)

							Spacer()
							GlossyCircle(color: network.endpoint.isEmpty ? .red : .green)
								.frame(size: CGSize(width: geom.size.height, height: geom.size.height))
						}
					}
				}
				.listStyle(.inset(alternatesRowBackgrounds: true))
				.frame(size: geom.size)
			}
		}
	}
}

#Preview {
	NetworksView(appState: .constant(.init()), navigationModel: .constant(.init()))
}
