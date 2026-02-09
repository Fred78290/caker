//
//  HomeView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import GRPCLib
import SwiftUI

struct HomeView: View {
	@Binding var appState: AppState
	@State private var navigationModel = NavigationModel()
	@State private var presented: Bool = false
	@State private var mustShowDetailView: Bool = true
	@State private var window: NSWindow? = nil

	private var deleteButtonDisabled: Bool {
		switch navigationModel.selectedCategory {
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
				ToolbarItem(placement: .navigation) {
					Button("Delete", systemImage: "trash") {
						self.actionDelete()
					}.disabled(self.deleteButtonDisabled)
				}

				ToolbarItem(placement: .navigation) {
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

	var haveDetailView: Bool {
		guard navigationModel.selectedCategory != .virtualMachine else {
			return false
		}

		return true
	}


	var showDetailView: Bool {
		guard navigationModel.selectedCategory != .virtualMachine else {
			return false
		}

		switch navigationModel.selectedCategory {
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
		switch navigationModel.selectedCategory {
		case .virtualMachine:
			VirtualMachineWizard(sheet: true)
				.colorSchemeForColor()
				.restorationState(.disabled)
				.frame(minWidth: 700, minHeight: 670)
		case .networks:
			NetworkWizard(appState: _appState)
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
		switch navigationModel.selectedCategory {
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
