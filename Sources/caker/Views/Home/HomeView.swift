//
//  HomeView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import SwiftUI

struct HomeView: View {
	@Binding var appState: AppState
	@State private var navigationModel = NavigationModel()

	var body: some View {
		NavigationSplitView {
			SideBarView(navigationModel: $navigationModel)
		} content: {
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
		} detail: {
			Text(navigationModel.selectedCategory.title)
		}
    }
}

#Preview {
	HomeView(appState: .constant(.init()))
}
