//
//  HomeViewTabView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import SwiftUI
import GRPCLib

struct HomeViewTabView: View {
	@Binding var appState: AppState
	@State private var navigationModel = NavigationModel()
	@State var presented: Bool = false
	@State var mustShowDetailView: Bool = true

	var body: some View {
		TabView(selection: $navigationModel.selectedCategory) {
			
		}
		self.navigationView.toolbar {
			ToolbarItem(placement: .navigation) {
				Button("Plus", systemImage: "plus") {
					self.actionPlus()
				}
			}

			ToolbarItem(placement: .primaryAction) {
				Button("Detail", systemImage: "sidebar.squares.right") {
					self.mustShowDetailView.toggle()
				}
			}
		}
		.sheet(isPresented: $presented) {
			self.sheet
		}
	}

	@ViewBuilder
	var navigationView: some View {
		if self.showDetailView {
			NavigationSplitView(columnVisibility: $navigationModel.navigationSplitViewVisibility) {
				self.sidebar
			} content: {
				self.content.navigationSplitViewColumnWidth(min: self.minContentSize, ideal: self.idealContentSize)
			} detail: {
				self.detail.navigationSplitViewColumnWidth(min: self.idealDetailSize, ideal: self.idealDetailSize, max: self.idealDetailSize)
			}
			.navigationSplitViewStyle(.prominentDetail)
			.onChange(of: navigationModel.selectedCategory) { oldValue, newValue in
				self.selectedCategoryDidChanged(oldValue, newValue)
			}
		} else {
			NavigationSplitView(columnVisibility: $navigationModel.navigationSplitViewVisibility) {
				self.sidebar
			} detail: {
				self.content.navigationSplitViewColumnWidth(min: self.minContentSize, ideal: self.idealContentSize)
			}.onChange(of: navigationModel.selectedCategory) { oldValue, newValue in
				self.selectedCategoryDidChanged(oldValue, newValue)
			}
		}
	}

	func selectedCategoryDidChanged(_ oldValue: Category, _ newValue: Category) {
		func clearSelectection(_ category: Category) {
			switch category {
			case .virtualMachine:
				navigationModel.selectedVirtualMachine = nil
			case .networks:
				navigationModel.selectedNetwork = nil
			case .images:
				navigationModel.selectedRemote = nil
			case .templates:
				navigationModel.selectedTemplate = nil
			}
		}
		
		clearSelectection(oldValue)
		clearSelectection(newValue)
	}

	var showDetailView: Bool {
		guard mustShowDetailView else {
			switch navigationModel.selectedCategory {
			case .virtualMachine:
				return false
			case .networks:
				return navigationModel.selectedNetwork != nil
			case .images:
				return navigationModel.selectedRemote != nil
			case .templates:
				return navigationModel.selectedTemplate != nil
			}
		}

		return navigationModel.selectedCategory != .virtualMachine
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

	var idealDetailSize: CGFloat {
		switch navigationModel.selectedCategory {
		case .images:
			return 200
		case .templates:
			return 200
		case .networks:
			return 450
		case .virtualMachine:
			return 200
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
		}
	}
	
	@ViewBuilder
	var detail: some View {
		switch navigationModel.selectedCategory {
		case .virtualMachine:
			Text("Hello, VM!")
		case .networks:
			if let selectedNetwork = navigationModel.selectedNetwork {
				NetworkDetailView(State(wrappedValue: selectedNetwork))
			} else {
				NetworkDetailView(State(wrappedValue: BridgedNetwork(name: "nat", mode: .nat, description: "NAT shared network", gateway: "", interfaceID: "nat", endpoint: "")))
			}
		case .images:
			Text("Hello, Remote!")
		case .templates:
			Text("Hello, Template!")
		}
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
