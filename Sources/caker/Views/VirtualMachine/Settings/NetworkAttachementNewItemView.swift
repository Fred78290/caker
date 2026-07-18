//
//  NetworkAttachementNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//
import ArgumentParser
import CakedLib
import GRPCLib
import SwiftUI
import Virtualization

extension [BridgeAttachement] {
	func editItem(_ editItem: BridgeAttachement.ID?, name: String) -> BridgeAttachement {
		if let editItem = editItem {
			return self.first(where: { $0.id == editItem }) ?? .init(network: name, mode: .auto)
		} else {
			return .init(network: name, mode: .auto)
		}
	}
}

struct NetworkAttachementNewItemView: View {
	@Binding private var networks: [BridgeAttachement]
	@State private var newItem: BridgeAttachement
	private let editItem: BridgeAttachement.ID?

	private static let names: [String] = AppState.shared.networks.compactMap {
		$0.mode != .nat ? $0.name : nil
	}

	init(_ networks: Binding<[BridgeAttachement]>, editItem: BridgeAttachement.ID? = nil) {
		self._networks = networks
		self.editItem = editItem
		self.newItem = networks.wrappedValue.editItem(editItem, name: Self.names.first ?? "nat")
	}

	var body: some View {
		EditableListNewItem($networks, currentItem: $newItem, editItem: editItem) {
			Section("New network attachment") {
				NetworkAttachementDetailView(currentItem: $newItem, readOnly: false)
			}
		} validateItem: { item in
			if self.networks.contains(where: { $0.network == item.network }) {
				return (false, String(localized: "Network already exists"))
			}

			if item.network.isEmpty || item.network == "nat" {
				return (false, String(localized: "Please select a network"))
			}

			return (true, nil)
		}
	}
}

#Preview {
	NetworkAttachementNewItemView(.constant([]))
}
