//
//  HomeView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import GRPCLib
import SwiftUI

struct HomeView: View {
	@Environment(\.appearsActive) private var appearsActive

	private let appState = AppState.shared

	@State private var navigationModel = NavigationModel()
	@State private var presented: Bool = false
	@State private var mustShowDetailView: Bool = true
	@State private var window: NSWindow? = nil
	@State private var selectedCategory: Category = .virtualMachine

	private var deleteButtonDisabled: Bool {
		switch self.selectedCategory {
		case .templates:
			return navigationModel.selectedTemplate == nil
		case .virtualMachine:
			guard let vm = navigationModel.selectedVirtualMachine else {
				return true
			}

			return vm.status == .running
		case .networks:
			guard let network = navigationModel.selectedNetwork else {
				return true
			}

			return network.usedBy != 0 || [.nat, .bridged].contains(network.mode)
		case .images:
			return navigationModel.selectedTemplate == nil
		}
	}

	var body: some View {
		self.navigationView
			.toolbar {
				ToolbarItemGroup(placement: .navigation) {
					Button("Delete", systemImage: "trash") {
						self.actionDelete()
					}.disabled(self.deleteButtonDisabled)

					Button("Plus", systemImage: "plus") {
						self.actionPlus()
					}
				}

				if self.haveDetailView {
					ToolbarItem(placement: .automatic) {
						Button("Detail", systemImage: "sidebar.squares.right") {
							self.mustShowDetailView.toggle()
						}
					}
				} else {
					ToolbarItem(placement: .automatic) {
						connectButton
					}.backgroundVisibility(false)
				}
			}
			.sheet(isPresented: $presented) {
				self.sheet
			}
			.onChange(of: self.appState.connectionMode) {
				self.navigationModel.resetSelections()
			}.onReceive(AppState.AppStateChanged) { notification in
				self.navigationModel.selectedTemplate = nil
				self.navigationModel.selectedVirtualMachine = nil
				self.navigationModel.selectedNetwork = nil
				self.navigationModel.selectedTemplate = nil

				if self.appearsActive {
					self.appState.currentDocument = nil
				}
			}
	}

	@ViewBuilder
	var connectButton: some View {
		if self.appState.connectionMode == .remote {
			Button("Disconnect", systemImage: "rectangle.connected.to.line.below") {
				self.appState.connectToLocal()
			}
			.foregroundStyle(.green)
			.font(.system(size: 10, weight: .regular, design: .default))
		} else {
			Image(systemName: "circle")
				.resizable()
				.renderingMode(.template)
				.foregroundStyle(self.appState.connectionMode == .app ? .red : .green)
				.aspectRatio(contentMode: .fit)
				.opacity(0.8)
				.frame(width: 24, height: 24)
				.padding(4)
				.overlay {
					Image(systemName: "app.connected.to.app.below.fill")
						.resizable()
						.renderingMode(.template)
						.foregroundStyle(self.appState.connectionMode == .app ? .red : .green)
						.aspectRatio(contentMode: .fit)
						.opacity(0.8)
						.frame(width: 14, height: 14)
						.padding(4)
				}
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

		navigationModel.newSelectedCategory(newValue)

		clearSelectection(oldValue)
		clearSelectection(newValue)
	}

	var haveDetailView: Bool {
		guard self.selectedCategory != .virtualMachine else {
			return false
		}

		return true
	}


	var showDetailView: Bool {
		guard self.selectedCategory != .virtualMachine else {
			return false
		}

		switch self.selectedCategory {
		case .virtualMachine:
			return false
		case .networks:
			guard navigationModel.selectedNetwork != nil else {
				return false
			}
		case .images:
			guard navigationModel.selectedRemote != nil else {
				return false
			}
		case .templates:
			guard navigationModel.selectedTemplate != nil else {
				return false
			}
		}

		return mustShowDetailView
	}

	var minContentSize: CGFloat? {
		switch self.selectedCategory {
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
		switch self.selectedCategory {
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
		switch self.selectedCategory {
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
		switch self.selectedCategory {
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
		SideBarView(categories: NavigationModel.categories, selectedCategory: $selectedCategory)
			.frame(minWidth: 200, maxWidth: 200)
			.navigationSplitViewColumnWidth(200)
			.navigationSplitViewStyle(.prominentDetail)
			.onChange(of: self.selectedCategory) { oldValue, newValue in
				self.selectedCategoryDidChanged(oldValue, newValue)
			}
			.windowAccessor($window) {
				if let window = $0 {
					window.titlebarAppearsTransparent = true
                    window.titleVisibility = .visible
                    window.toolbarStyle = .unified
				}
			}
	}

	@ViewBuilder
	var content: some View {
		GeometryReader { geometry in
			switch self.selectedCategory {
			case .images:
				RemotesView(navigationModel: $navigationModel)
			case .templates:
				TemplatesView(navigationModel: $navigationModel)
			case .networks:
				NetworksView(navigationModel: $navigationModel)
			case .virtualMachine:
				VirtualMachinesView(navigationModel: $navigationModel, size: geometry.size)
			}
		}.navigationSplitViewColumnWidth(min: self.minContentSize, ideal: self.idealContentSize)
	}

	@ViewBuilder
	var detail: some View {
		GeometryReader { geometry in
			switch self.selectedCategory {
			case .virtualMachine:
				Text("Hello, VM!")
			case .networks:
				if navigationModel.selectedNetwork != nil {
					NetworkDetailView(
						Binding<BridgedNetwork>(
							get: {
								navigationModel.selectedNetwork!
							},
							set: { newValue in
								navigationModel.selectedNetwork = newValue
							}
						),
						reloadNetwork: Binding<Bool>(
							get: {
								false
							},
							set: { newValue in
								if newValue {
									DispatchQueue.main.async {
										self.appState.reloadNetworks()

										navigationModel.selectedNetwork = self.appState.networks.first {
											$0.id == navigationModel.selectedNetwork!.id
										}
									}
								}
							}
						)
					).background(Color(NSColor.tertiarySystemFill))
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
		switch self.selectedCategory {
		case .virtualMachine:
			VirtualMachineWizard(sheet: true)
				.colorSchemeForColor()
				.restorationState(.disabled)
				.frame(minWidth: 700, minHeight: 670)
		case .networks:
			NetworkWizard()
				.colorSchemeForColor()
				.restorationState(.disabled)
				.frame(size: CGSize(width: 600, height: 400))
		case .images:
			RemoteWizard()
				.colorSchemeForColor()
				.restorationState(.disabled)
		default:
			Text("Hello, World!")
		}
	}

	func actionDelete() {
		switch self.selectedCategory {
		case .virtualMachine:
			self.appState.deleteVirtualMachine(document: navigationModel.selectedVirtualMachine)
		case .networks:
			self.appState.deleteNetwork(name: navigationModel.selectedNetwork.name)
		case .images:
			self.appState.deleteRemote(name: navigationModel.selectedRemote.name)
		case .templates:
			self.appState.deleteTemplate(name: navigationModel.selectedTemplate.name)
		}
	}

	func actionPlus() {
		switch self.selectedCategory {
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
	HomeView()
}
