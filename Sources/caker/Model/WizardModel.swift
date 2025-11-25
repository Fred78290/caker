//
//  VirtualMachineWizard.swift
//  Caker
//
//  Created by Frederic BOLTZ on 29/10/2025.
//

struct WizardModel {
	enum SelectedItem: Int, Hashable, Comparable, Identifiable {
		static func < (lhs: WizardModel.SelectedItem, rhs: WizardModel.SelectedItem) -> Bool {
			return lhs.rawValue < rhs.rawValue
		}

		var id: Int {
			self.rawValue
		}

		case name
		case os
		case cpuAndRam
		case sharing
		case disk
		case network
		case ports
		case sockets
	}

	struct ItemView: @MainActor ToolbarSettingItem, Hashable {
		var id: SelectedItem
		var title: String
		var systemImage: String

		init(_ id: SelectedItem, title: String, systemImage: String) {
			self.title = title
			self.systemImage = systemImage
			self.id = id
		}
	}

	static let items: [ItemView] = [
		ItemView(.name, title: "Name", systemImage: "character.cursor.ibeam"),
		ItemView(.os, title: "Choose OS", systemImage: "cloud"),
		ItemView(.cpuAndRam, title: "CPU & Ram", systemImage: "cpu"),
		ItemView(.sharing, title: "Sharing", systemImage: "folder.badge.plus"),
		ItemView(.disk, title: "Disk", systemImage: "externaldrive.badge.plus"),
		ItemView(.network, title: "Network", systemImage: "network"),
		ItemView(.ports, title: "Ports", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath"),
		ItemView(.sockets, title: "Sockets", systemImage: "powerplug"),
	]
}
