//
//  HomeView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import GRPCLib
import SwiftUI
import CakeAgentLib

struct HomeView: View {
	@Environment(\.appearsActive) private var appearsActive

	private var appState = AppState.shared

	@State var navigationModel: NavigationModel
	@State private var presented: Bool = false
	@State private var mustShowDetailView: Bool = true
	@State private var window: NSWindow? = nil
	@State private var selectedCategory: Category = .virtualMachine

	init(navigationModel: NavigationModel) {
		self.navigationModel = navigationModel
	}

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
			return navigationModel.selectedRemote == nil
		case .tasks:
			// Cancellation is done per-row via context menu, not the toolbar Delete button.
			return true
		}
	}

	var body: some View {
		self.navigationView
			.toolbar {
				ToolbarItemGroup(placement: .navigation) {
					connectButton

					Button("Delete", systemImage: "trash") {
						self.actionDelete()
					}.disabled(self.deleteButtonDisabled)

					Button("Plus", systemImage: "plus") {
						self.actionPlus()
					}.disabled(self.selectedCategory == .templates || self.selectedCategory == .tasks)
				}

				if self.selectedCategory == .virtualMachine {
					ToolbarItem(placement: .automatic) {
						Picker("View mode", selection: $navigationModel.virtualMachinesViewMode) {
							ForEach(VirtualMachinesViewMode.allCases) { mode in
								Image(systemName: mode.iconName)
									.help(mode.label)
									.tag(mode)
							}
						}
						.pickerStyle(.segmented)
						.labelsHidden()
						.frame(width: 76)
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
					.colorSchemeForColor()
			}
			.onChange(of: self.appState.connectionMode) {
				self.navigationModel.resetSelections()
			}.onChange(of: self.appState.virtualMachines) {
				if let selectedVirtualMachine = navigationModel.selectedVirtualMachine, self.appState.findVirtualMachineDocument(selectedVirtualMachine.url) == nil {
					navigationModel.selectedVirtualMachine = nil
				}
			}.onChange(of: self.appState.networks) {
				if let selectedNetwork = navigationModel.selectedNetwork, self.appState.networkExists(name: selectedNetwork.name) == false {
					navigationModel.selectedNetwork = nil
				}
			}.onChange(of: self.appState.templates) {
				if let selectedTemplate = navigationModel.selectedTemplate, self.appState.templateExists(name: selectedTemplate.name) == false {
					navigationModel.selectedTemplate = nil
				}
			}.onChange(of: self.appState.remotes) {
				if let selectedRemote = navigationModel.selectedRemote, self.appState.remoteExists(name: selectedRemote.name) == false {
					navigationModel.selectedRemote = nil
				}
			}.onReceive(AppState.AppStateChanged) { notification in
				self.navigationModel.selectedTemplate = nil
				self.navigationModel.selectedVirtualMachine = nil
				self.navigationModel.selectedNetwork = nil
				self.navigationModel.selectedRemote = nil

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
			case .tasks:
				break
			}
		}

		navigationModel.newSelectedCategory(newValue)

		clearSelectection(oldValue)
		clearSelectection(newValue)
	}

	var haveDetailView: Bool {
		guard self.selectedCategory != .virtualMachine else {
			// Mosaic mode already shows a live screenshot/status on every tile, so the detail
			// column only makes sense once the VM collection is shown as a plain list.
			return self.navigationModel.virtualMachinesViewMode == .list
		}

		// A task entry (id + title) is too sparse to warrant its own detail column.
		guard self.selectedCategory != .tasks else {
			return false
		}

		return true
	}


	var showDetailView: Bool {
		switch self.selectedCategory {
		case .virtualMachine:
			guard self.navigationModel.virtualMachinesViewMode == .list, navigationModel.selectedVirtualMachine != nil else {
				return false
			}
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
		case .tasks:
			return false
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
		case .tasks:
			return nil
		case .virtualMachine:
			guard self.navigationModel.virtualMachinesViewMode == .mosaic else {
				return nil
			}

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
		case .tasks:
			return 200
		case .virtualMachine:
			guard self.navigationModel.virtualMachinesViewMode == .mosaic else {
				return 240
			}

			return (VirtualMachinesView.cellWidth + (VirtualMachinesView.cellSpacing * 2)) * max(1, min(2, CGFloat(self.navigationModel.documents.count)))
		}
	}

	var idealDetailSize: CGFloat {
		switch self.selectedCategory {
		case .images:
			return 450
		case .templates:
			return 400
		case .networks:
			return 450
		case .tasks:
			return 400
		case .virtualMachine:
			return 340
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
		case .tasks:
			return 200
		case .virtualMachine:
			return (VirtualMachinesView.cellWidth + VirtualMachinesView.cellSpacing * 2) * max(1, min(3, CGFloat(self.navigationModel.documents.count)))
		}
	}

	/// `NavigationModel.categories` itself stays the full static list (other code may reference it
	/// generically) — the `.tasks` category is filtered out here instead, only when there's no
	/// separate `caked` process to have tasks in (`.app` connection mode, i.e. VMs running embedded
	/// in-process). See `TasksHandler`'s doc comment for why there's no `.app`-mode fallback for it.
	var visibleCategories: [Category] {
		NavigationModel.categories.filter { $0 != .tasks || self.appState.connectionMode != .app }
	}

	@ViewBuilder
	var sidebar: some View {
		SideBarView(categories: self.visibleCategories, selectedCategory: $selectedCategory)
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
				RemotesView(navigationModel: navigationModel)
			case .templates:
				TemplatesView(navigationModel: navigationModel)
			case .networks:
				NetworksView(navigationModel: navigationModel)
			case .virtualMachine:
				VirtualMachinesView(navigationModel: navigationModel, columns: VirtualMachinesView.buildColumns(geometry.size))
			case .tasks:
				TasksView(navigationModel: navigationModel)
			}
		}.navigationSplitViewColumnWidth(min: self.minContentSize, ideal: self.idealContentSize)
	}

	@ViewBuilder
	var detail: some View {
		GeometryReader { geometry in
			switch self.selectedCategory {
			case .virtualMachine:
				if let selectedVirtualMachine = navigationModel.selectedVirtualMachine {
					VirtualMachineDetailView(vm: selectedVirtualMachine)
						.background(Color(NSColor.tertiarySystemFill))
				} else {
					EmptyView()
				}
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
				if let selectedRemote = navigationModel.selectedRemote {
					RemoteDetailView(remote: selectedRemote)
						.background(Color(NSColor.tertiarySystemFill))
				} else {
					EmptyView()
				}
			case .templates:
				if let selectedTemplate = navigationModel.selectedTemplate {
					TemplateDetailView(template: selectedTemplate)
						.background(Color(NSColor.tertiarySystemFill))
				} else {
					EmptyView()
				}
			case .tasks:
				EmptyView()
			}
		}
		.navigationSplitViewColumnWidth(min: self.idealDetailSize, ideal: self.idealDetailSize, max: self.idealDetailSize)
	}

	@ViewBuilder
	var sheet: some View {
		switch self.selectedCategory {
		case .virtualMachine:
			VirtualMachineWizard(connectionManager: AppState.shared.connectionManager, sheet: true)
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
			if let selectedVirtualMachine = navigationModel.selectedVirtualMachine {
				selectedVirtualMachine.deleteVirtualMachine()
				navigationModel.selectedVirtualMachine = nil
			}
		case .networks:
			if let selectedNetwork = navigationModel.selectedNetwork {
				self.appState.deleteNetwork(name: selectedNetwork.name)
				navigationModel.selectedNetwork = nil
			}
		case .images:
			if let selectedRemote = navigationModel.selectedRemote {
				self.appState.deleteRemote(name: selectedRemote.name)
				navigationModel.selectedRemote = nil
			}
		case .templates:
			if let selectedTemplate = navigationModel.selectedTemplate {
				self.appState.deleteTemplate(name: selectedTemplate.name)
				navigationModel.selectedTemplate = nil
			}
		case .tasks:
			// Cancellation is done per-row via TasksView's own context menu, not this toolbar button
			// (see deleteButtonDisabled, which keeps it disabled for this category).
			break
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
			self.presented = false
		case .tasks:
			self.presented = false
		}
	}
}

#Preview {
    HomeView(navigationModel: NavigationModel())
}
