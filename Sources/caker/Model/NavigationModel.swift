import CakedLib
import GRPCLib
//
//  NavigationModel.swift
//  Caker
//
//  Created by Frederic BOLTZ on 09/06/2025.
//
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

	var title: String {
		switch self {
		case .images:
			return "Cloud images"
		case .templates:
			return "My templates"
		case .networks:
			return "Networks"
		case .virtualMachine:
			return "Virtual Machines"
		}
	}
}

class NavigationModel: ObservableObject, Observable {
	@Published var columnVisibility: NavigationSplitViewVisibility = .all
	@Published var selectedCategory: Category = .images
	@Published var selectedElement: SelectedElement? = nil
	@Published var navigationSplitViewVisibility: NavigationSplitViewVisibility = .all
	@Published var selectedRemote: RemoteEntry? = nil
	@Published var selectedTemplate: TemplateEntry? = nil
	@Published var selectedNetwork: BridgedNetwork? = nil
	@Published var selectedVirtualMachine: VirtualMachine? = nil

	var categories: [Category] = [.virtualMachine, .networks, .templates, .images]
}

extension NavigationModel: Equatable {
	static func == (lhs: NavigationModel, rhs: NavigationModel) -> Bool {
		if ObjectIdentifier(lhs) == ObjectIdentifier(rhs) {
			return true
		}

		return lhs.columnVisibility == rhs.columnVisibility && lhs.selectedCategory == rhs.selectedCategory
	}
}
