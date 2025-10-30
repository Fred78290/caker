//
//  NetworksView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import GRPCLib
import SwiftUI

struct NetworksView: View {
	@Binding var appState: AppState
	@Binding var navigationModel: NavigationModel
	@State private var selection: BridgedNetwork.ID? = nil
	@State private var disabled: Bool = false

	var body: some View {
		GeometryReader { geom in
			ScrollView {
				VStack(alignment: .center) {
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
						Table(appState.networks, selection: $navigationModel.selectedNetwork) {
							
						}
						List(selection: $navigationModel.selectedNetwork) {
							ForEach($appState.networks) { network in
								HStack {
								}
							}
						}
					}
				}
			}
		}
	}
}

#Preview {
	NetworksView(appState: .constant(.init()), navigationModel: .constant(.init()))
}
