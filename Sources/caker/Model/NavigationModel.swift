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

enum Category: Int, CaseIterable, Codable, Identifiable {
	case virtualMachine
	case networks
	case images
	case templates

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
		}
	}
}

@Observable class NavigationModel {
	var columnVisibility: NavigationSplitViewVisibility = .all
	var selectedElement: SelectedElement? = nil
	var navigationSplitViewVisibility: NavigationSplitViewVisibility = .all
	var navigationSplitViewColumn: NavigationSplitViewColumn = .content
	var selectedRemote: RemoteEntry! = nil
	var selectedTemplate: TemplateEntry! = nil
	var selectedNetwork: BridgedNetwork! = nil
	var selectedVirtualMachine: VirtualMachineDocument! = nil
	
	static var categories: [Category] = [.virtualMachine, .networks]
	
	init(selectedCategory: Category = .virtualMachine) {
		self.newSelectedCategory(selectedCategory)
	}

	func newSelectedCategory(_ category: Category) {
		switch category {
		case .virtualMachine:
			self.navigationSplitViewColumn = .detail
			self.navigationSplitViewVisibility = .doubleColumn
		case .networks:
			self.navigationSplitViewColumn = .sidebar
			self.navigationSplitViewVisibility = .all
		case .templates:
			self.navigationSplitViewColumn = .sidebar
			self.navigationSplitViewVisibility = .all
		case .images:
			self.navigationSplitViewColumn = .sidebar
			self.navigationSplitViewVisibility = .all
		}
	}

	func resetSelections() {
		self.selectedRemote = nil
		self.selectedTemplate = nil
		self.selectedNetwork = nil
		self.selectedVirtualMachine = nil
	}
}
