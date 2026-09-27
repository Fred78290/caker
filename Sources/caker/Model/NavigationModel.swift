//
//  NavigationModel.swift
//  Caker
//
//  Created by Frederic BOLTZ on 09/06/2025.
//
import CakedLib
import GRPCLib
import SwiftUI

enum SelectedElement: Identifiable, Hashable, Equatable {
	static func == (lhs: SelectedElement, rhs: SelectedElement) -> Bool {
		lhs.id == rhs.id
	}

	case none
	case image(String, ImageInfo)
	case template(String)
	case virtualMachine(String)

	var id: String {
		switch self {
		case .none:
			return "none"
		case .image(let remote, let imageInfo):
			return "\(remote):\(imageInfo.id)"
		case .template(let templateId):
			return "template:\(templateId)"
		case .virtualMachine(let vmId):
			return "vm:\(vmId)"
		}
	}
}

/// How `VirtualMachinesView` lays out the VM collection — persisted via `@AppStorage` under the
/// key `"VirtualMachinesViewMode"`, read independently by both `VirtualMachinesView` (to pick its
/// layout) and `HomeView` (to decide whether the detail column/toggle applies to the `.virtualMachine`
/// category at all) rather than threading it through `NavigationModel`, matching how other simple
/// view-level preferences (e.g. `appearancePreference`) are already shared across unrelated views
/// in this codebase.
enum VirtualMachinesViewMode: String, CaseIterable, Identifiable, Codable {
	case mosaic
	case list

	var id: Self { self }

	var iconName: String {
		switch self {
		case .mosaic: return "square.grid.2x2"
		case .list: return "list.bullet"
		}
	}

	var label: LocalizedStringKey {
		switch self {
		case .mosaic: return "Mosaic"
		case .list: return "List"
		}
	}
}

enum Category: Int, CaseIterable, Codable, Identifiable {
	case virtualMachine
	case networks
	case images
	case templates
	case tasks
	case cache
	case compose

	var id: Self { self }
	var iconName: String {
		switch self {
		case .images:
			return "books.vertical"
		case .templates:
			return "books.vertical.fill"
		case .networks:
			return "network"
		case .virtualMachine:
			return "display"
		case .tasks:
			return "hourglass"
		case .cache:
			return "externaldrive"
		case .compose:
			return "square.stack.3d.up"
		}
	}

	var title: LocalizedStringKey {
		switch self {
		case .images:
			return "Cloud images"
		case .templates:
			return "My templates"
		case .networks:
			return "Networks"
		case .virtualMachine:
			return "Virtual machines"
		case .tasks:
			return "Tasks"
		case .cache:
			return "Image cache"
		case .compose:
			return "Compose"
		}
	}
}

@Observable class NavigationModel {
	var columnVisibility: NavigationSplitViewVisibility = .all
	var selectedElement: SelectedElement? = nil
	var navigationSplitViewVisibility: NavigationSplitViewVisibility = .all
	var navigationSplitViewColumn: NavigationSplitViewColumn = .content
	var selectedRemote: RemoteEntry? = nil
	var selectedTemplate: TemplateEntry? = nil
	var selectedNetwork: BridgedNetwork? = nil
	var selectedVirtualMachine: VirtualMachineDocumentState? = nil
	var selectedTask: Caked_TaskEntry? = nil
	var selectedCachedImage: VirtualMachineInfo? = nil
	var selectedComposeProject: ComposeReplyList.ComposeInfo? = nil
	/// Bumped by the toolbar after it changes the image cache so `ImageCacheView` reloads.
	var cacheReloadToken: Int = 0
	/// Bumped whenever a compose action (up/down/rm) completes so `ComposeView` reloads sooner than
	/// its next poll tick — mirrors `cacheReloadToken`.
	var composeReloadToken: Int = 0
	var documents: VirtualMachineDocumentStates = [:]
	var virtualMachinesViewMode: VirtualMachinesViewMode = AppState.shared.virtualMachinesViewMode {
		didSet {
			AppState.shared.virtualMachinesViewMode = self.virtualMachinesViewMode
		}
	}

	/// Set by `CakerMenuBarExtraScene` (e.g. a compose project's "Open" action, or "New compose
	/// project…") right before calling `openWindow(id: "home")`, so `HomeView` can switch its own
	/// local `selectedCategory` once the window exists — that state isn't itself part of
	/// `NavigationModel` (see `VirtualMachinesViewMode`'s own doc comment above for why simple
	/// view-local preferences live outside this model), so this is the bridge for "switch to this
	/// category" requests coming from outside the window that owns it.
	var pendingSidebarCategory: Category? = nil
	/// Set alongside `pendingSidebarCategory = .compose` when the menu bar's "New compose project…"
	/// entry should also pop the Compose Editor sheet open once the window is showing the category.
	var pendingNewComposeProject: Bool = false
	/// Set alongside `pendingSidebarCategory = .compose` by a project's "Open" menu-bar action.
	/// Deliberately a name, not the `ComposeReplyList.ComposeInfo` itself: switching `selectedCategory`
	/// clears the category's current selection first (see `HomeView.selectedCategoryDidChanged`), so
	/// setting `selectedComposeProject` directly here would just be wiped out again — `ComposeView`
	/// applies this by name once its own poll-driven refresh has a matching, up-to-date project to
	/// select, then clears it.
	var pendingComposeProjectName: String? = nil

	static var categories: [Category] = [.virtualMachine, .networks, .templates, .images, .cache, .compose, .tasks]

	init(selectedCategory: Category = .virtualMachine) {
		self.newSelectedCategory(selectedCategory)
	}
	
	func newSelectedCategory(_ category: Category) {
		switch category {
		case .virtualMachine:
			if self.virtualMachinesViewMode == .list {
				self.navigationSplitViewColumn = .sidebar
				self.navigationSplitViewVisibility = .all
			} else {
				self.navigationSplitViewColumn = .detail
				self.navigationSplitViewVisibility = .doubleColumn
			}
		case .networks:
			self.navigationSplitViewColumn = .sidebar
			self.navigationSplitViewVisibility = .all
		case .templates:
			self.navigationSplitViewColumn = .sidebar
			self.navigationSplitViewVisibility = .all
		case .images:
			self.navigationSplitViewColumn = .sidebar
			self.navigationSplitViewVisibility = .all
		case .tasks, .cache, .compose:
			self.navigationSplitViewColumn = .sidebar
			self.navigationSplitViewVisibility = .all
		}
	}

	func resetSelections() {
		self.selectedRemote = nil
		self.selectedTemplate = nil
		self.selectedNetwork = nil
		self.selectedVirtualMachine = nil
		self.selectedCachedImage = nil
		self.selectedComposeProject = nil
	}
	
	func sync(with appState: AppState) {
		self.documents.removeAll()
		
		appState.documents.forEach {
			self.documents.updateValue(.init($0), forKey: $0.url)
		}
	}

	@MainActor func addStateVirtualMachineDocument(with document: VirtualMachineDocument) {
		if self.documents[document.url] == nil {
			self.documents.updateValue(.init(document), forKey: document.url)
		}
	}

	@MainActor func removeStateVirtualMachineDocument(with url: URL) {
		self.documents.removeValue(forKey: url)
	}

	@MainActor func updateStateVirtualMachineDocument(with document: VirtualMachineDocument) {
		guard let vm = self.documents[document.url] else { return }
		
		vm.sync(with: document)
	}
}
