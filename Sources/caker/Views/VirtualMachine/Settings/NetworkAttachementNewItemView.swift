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
	func editItem(_ editItem: BridgeAttachement.ID?) -> BridgeAttachement {
		if let editItem = editItem {
			return self.first(where: { $0.id == editItem }) ?? .init(network: "nat", mode: .auto)
		} else {
			return .init(network: "nat", mode: .auto)
		}
	}
}

struct NetworkAttachementNewItemView: View {
	@Binding private var networks: [BridgeAttachement]
	@State private var newItem: BridgeAttachement
	private let editItem: BridgeAttachement.ID?

	let names: [String] = try! NetworksHandler.networks(runMode: .app).map { $0.name }

	init(_ networks: Binding<[BridgeAttachement]>, editItem: BridgeAttachement.ID? = nil) {
		self._networks = networks
		self.editItem = editItem
		self.newItem = networks.wrappedValue.editItem(editItem)
	}

	var body: some View {
		EditableListNewItem($networks, currentItem: $newItem, editItem: editItem) {
			Section("New network attachment") {
				NetworkAttachementDetailView(currentItem: $newItem, readOnly: false)
			}
		}
	}
}

#Preview {
	NetworkAttachementNewItemView(.constant([]))
}
