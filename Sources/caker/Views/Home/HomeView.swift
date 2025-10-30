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
		NavigationSplitView(columnVisibility: $navigationModel.navigationSplitViewVisibility, sidebar: {
			SideBarView(navigationModel: $navigationModel)
				.frame(minWidth: 200, maxWidth: 200)
				.navigationSplitViewColumnWidth(200)
		}, content: {
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
		}, detail: {
			Text("Hello, World!")
		})
		.frame(minWidth: 500, minHeight: 400)
		.colorSchemeForColor(self.colorScheme)
		.onChange(of: self.colorScheme) { _, newValue in
			Color.colorScheme = newValue
		}
	}
}

#Preview {
	HomeView(appState: .constant(.init()))
}
