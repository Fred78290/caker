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
	@State var selectedItem: BridgeAttachement? = nil

	var body: some View {
		EditableList($networks, selection: $selectedItem) { $item in
			NetworkAttachementDetailView(currentItem: $item)
		}.onEditItem(selection: $selectedItem) {
			NetworkAttachementNewItemView(networks: $networks)
		} deleteItem: {
			self.networks.removeAll {
				$0.id == selectedItem?.id
			}
		}
	}
}

#Preview {
	NetworkAttachementView(networks: .constant([]))
}
