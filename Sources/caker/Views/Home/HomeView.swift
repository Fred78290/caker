//
//  HomeView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import SwiftUI
import GRPCLib

struct HomeView: View {
	@Binding var appState: AppState
	@State private var navigationModel = NavigationModel()
	@State var presented: Bool = false
	@State var mustShowDetailView: Bool?
	@State var window: NSWindow? = nil

	var body: some View {
		self.navigationView
		.toolbar {
			if navigationModel.selectedCategory == .templates {
				ToolbarItem(placement: .navigation) {
					Button("Delete", systemImage: "trash") {
						self.actionDelete()
					}.disabled(navigationModel.selectedTemplate == nil)
				}
			} else if navigationModel.selectedCategory == .virtualMachine {
				ToolbarItem(placement: .navigation) {
					Button("Delete", systemImage: "trash") {
						self.actionDelete()
					}.disabled(navigationModel.selectedVirtualMachine == nil)
				}

				ToolbarItem(placement: .navigation) {
					Button("Plus", systemImage: "plus") {
						self.actionPlus()
					}
				}
			} else {
				ToolbarItemGroup(placement: .navigation) {
					if navigationModel.selectedCategory == .networks {
						Button("Delete", systemImage: "trash") {
							self.actionDelete()
						}.disabled(navigationModel.selectedNetwork == nil)
					} else {
						Button("Delete", systemImage: "trash") {
							self.actionPlus()
						}.disabled(navigationModel.selectedRemote == nil)
					}

					Button("Plus", systemImage: "plus") {
						self.actionPlus()
					}
				}

				ToolbarItem(placement: .primaryAction) {
					Button("Detail", systemImage: "sidebar.squares.right") {
						if self.mustShowDetailView == nil {
							mustShowDetailView = false
						} else {
							self.mustShowDetailView?.toggle()
						}
					}
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
				self.content
			} detail: {
				self.detail
			}
		} else {
			NavigationSplitView(columnVisibility: $navigationModel.navigationSplitViewVisibility) {
				self.sidebar
			} detail: {
				self.content
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
		guard navigationModel.selectedCategory != .virtualMachine else {
			return false
		}

		guard let mustShowDetailView else {
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

		return mustShowDetailView
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
			.navigationSplitViewStyle(.prominentDetail)
			.onChange(of: navigationModel.selectedCategory) { oldValue, newValue in
				self.selectedCategoryDidChanged(oldValue, newValue)
			}
			.windowAccessor($window) {
				if let window = $0 {
					window.titlebarAppearsTransparent = true
				}
			}
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
		GeometryReader { geometry in
			switch navigationModel.selectedCategory {
			case .virtualMachine:
				Text("Hello, VM!")
			case .networks:
				if navigationModel.selectedNetwork != nil {
					NetworkDetailView(Binding<BridgedNetwork>(
						get: {
							navigationModel.selectedNetwork!
						},
						set: { newValue in
							navigationModel.selectedNetwork = newValue
						}
					)).background(Color(NSColor.tertiarySystemFill))
				} else {
					EmptyView()
				}
			case .images:
				Text("Hello, Remote!")
			case .templates:
				Text("Hello, Template!")
			}
		}
		.navigationSplitViewColumnWidth(min: self.idealDetailSize, ideal: self.idealDetailSize, max: self.idealDetailSize)
	}

	@ViewBuilder
	var sheet: some View {
		switch navigationModel.selectedCategory {
		case .virtualMachine:
			VirtualMachineWizard(appState: _appState, sheet: true)
				.colorSchemeForColor()
				.restorationState(.disabled)
				.frame(minWidth: 700, minHeight: 670)
		case .networks:
			NetworkWizard(appState: _appState)
				.colorSchemeForColor()
				.restorationState(.disabled)
				.frame(size: CGSize(width: 300, height: 250))
		case .images:
			RemoteWizard()
				.colorSchemeForColor()
				.restorationState(.disabled)
		default:
			Text("Hello, World!")
		}
	}

	func actionDelete() {
		
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
