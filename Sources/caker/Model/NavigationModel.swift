//
//  NavigationModel.swift
//  Caker
//
//  Created by Frederic BOLTZ on 09/06/2025.
//
import SwiftUI
import GRPCLib
import CakedLib


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
	case images
	case networks
	case templates
	case virtualMachine
	
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

	var categories: [Category] = [.images, .templates, .networks, .virtualMachine]
}

extension NavigationModel: Equatable {
	static func ==(lhs: NavigationModel, rhs: NavigationModel) -> Bool {
		if ObjectIdentifier(lhs) == ObjectIdentifier(rhs) {
			return true
		}

		return lhs.columnVisibility == rhs.columnVisibility &&
		lhs.selectedCategory == rhs.selectedCategory
	}
}
