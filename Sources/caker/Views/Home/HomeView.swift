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
		if navigationModel.selectedCategory == .virtualMachine {
			NavigationSplitView(columnVisibility: $navigationModel.navigationSplitViewVisibility) {
				self.sidebar
			} detail: {
				self.content
			}
		} else {
			NavigationSplitView(columnVisibility: $navigationModel.navigationSplitViewVisibility){
				self.sidebar
			} content: {
				self.content
			} detail: {
				self.detail
			}
		}
	}

	@ViewBuilder
	var sidebar: some View {
		SideBarView(navigationModel: $navigationModel)
			.frame(minWidth: 200, maxWidth: 200)
			.navigationSplitViewColumnWidth(200)
	}

	@ViewBuilder
	var content: some View {
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
	
	@ViewBuilder
	var detail: some View {
		Text("Hello, World!")
	}
}

#Preview {
	HomeView(appState: .constant(.init()))
}
