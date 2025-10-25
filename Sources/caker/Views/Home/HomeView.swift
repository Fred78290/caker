//
//  HomeView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import SwiftUI

struct HomeView: View {
	@Environment(\.colorScheme) var colorScheme
	@Binding var appState: AppState
	@State private var navigationModel = NavigationModel()
	@State var columns: NavigationSplitViewVisibility = .all

	var body: some View {
		NavigationSplitView {
			SideBarView(navigationModel: $navigationModel)
				.frame(minWidth: 200, maxWidth: 200)
				.navigationSplitViewColumnWidth(200)
		} detail: {
			switch navigationModel.selectedCategory {
			case .images:
				RemotesView(appState: $appState, navigationModel: $navigationModel)
			case .templates:
				TemplatesView(appState: $appState, navigationModel: $navigationModel)
			case .networks:
				NetworksView(appState: $appState, navigationModel: $navigationModel)
			case .virtualMachine:
				VirtualMachinesView(appState: $appState, navigationModel: $navigationModel)
			}
		}
		.frame(minWidth: 500, minHeight: 400)
		.colorSchemeForColor(self.colorScheme)
		.frame(minWidth: 500, minHeight: 400)
	}
}

#Preview {
	HomeView(appState: .constant(.init()))
}
