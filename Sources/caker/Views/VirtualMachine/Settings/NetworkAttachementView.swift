//
//  NetworkAttachementView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//

import GRPCLib
import SwiftUI

struct NetworkAttachementView: View {
	@Binding var networks: [BridgeAttachement]
	@State private var selectedItems: Set<BridgeAttachement.ID> = []
	@State private var selection: BridgeAttachement.ID? = nil

	var body: some View {
		EditableList($networks, selection: $selection, selectedItems: $selectedItems) { $item in
			NetworkAttachementDetailView(currentItem: $item)
		}.onEditItem(selection: $selection, selectedItems: $selectedItems) {
			NetworkAttachementNewItemView(networks: $networks)
		} deleteItem: {
			selectedItems.forEach { selectedItem in
				self.networks.removeAll {
					$0.id == selectedItem
				}
			}
		}
	}
}

#Preview {
	NetworkAttachementView(networks: .constant([]))
}
