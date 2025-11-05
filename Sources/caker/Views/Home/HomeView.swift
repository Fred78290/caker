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
	@State var presented: Bool = false

	var body: some View {
		self.navigationView.toolbar {
			ToolbarItem(placement: .destructiveAction) {
				Button("Plus", systemImage: "plus") {
					self.actionPlus()
				}
			}
		}
		.sheet(isPresented: $presented) {
			self.sheet
		}
	}

	@ViewBuilder
	var navigationView: some View {
		if navigationModel.selectedCategory == .virtualMachine {
			NavigationSplitView(columnVisibility: $navigationModel.navigationSplitViewVisibility) {
				self.sidebar
			} detail: {
				self.content
			}
		} else {
			NavigationSplitView(columnVisibility: $navigationModel.navigationSplitViewVisibility) {
				self.sidebar
			} content: {
				self.content
			} detail: {
				self.detail
			}
		}
	}

	var minContentSize: CGFloat? {
		switch navigationModel.selectedCategory {
		case .images:
			return nil
		case .templates:
			return nil
		case .networks:
			return nil
		case .virtualMachine:
			return VirtualMachinesView.cellWidth + (VirtualMachinesView.cellSpacing * 2)
		}
	}

	var idealContentSize: CGFloat {
		switch navigationModel.selectedCategory {
		case .images:
			return 200
		case .templates:
			return 200
		case .networks:
			return 200
		case .virtualMachine:
			return (VirtualMachinesView.cellWidth + (VirtualMachinesView.cellSpacing * 2)) * max(1, min(2, CGFloat(self.appState.virtualMachines.count)))
		}
	}

	var maxContentSize: CGFloat {
		switch navigationModel.selectedCategory {
		case .images:
			return 200
		case .templates:
			return 200
		case .networks:
			return 200
		case .virtualMachine:
			return (VirtualMachinesView.cellWidth + VirtualMachinesView.cellSpacing * 2) * max(1, min(3, CGFloat(self.appState.virtualMachines.count)))
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
		GeometryReader { geometry in
			switch navigationModel.selectedCategory {
			case .images:
				RemotesView(appState: $appState, navigationModel: $navigationModel)
			case .templates:
				TemplatesView(appState: $appState, navigationModel: $navigationModel)
			case .networks:
				NetworksView(appState: $appState, navigationModel: $navigationModel)
			case .virtualMachine:
				VirtualMachinesView(appState: $appState, navigationModel: $navigationModel, size: geometry.size)
			}
		}.navigationSplitViewColumnWidth(min: self.minContentSize, ideal: self.idealContentSize)
	}
	
	@ViewBuilder
	var detail: some View {
		Text("Hello, World!")
	}

	@ViewBuilder
	var sheet: some View {
		switch navigationModel.selectedCategory {
		case .virtualMachine:
			VirtualMachineWizard(sheet: true)
				.colorSchemeForColor()
				.restorationState(.disabled)
				.frame(minWidth: 700, minHeight: 670)
		default:
			Text("Hello, World!")
		}
	}

	func actionPlus() {
		switch navigationModel.selectedCategory {
		case .virtualMachine:
			self.presented = true
		case .networks:
			self.presented = true
		case .images:
			self.presented = true
		case .templates:
			self.presented = true
		}
	}
}

#Preview {
	HomeView(appState: .constant(.init()))
}
