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
	@State private var selection: BridgeAttachement.ID? = nil

	var body: some View {
		EditableList($networks, selection: $selection) { $item in
			NetworkAttachementDetailView(currentItem: $item)
		}.onEditItem(selection: $selection) { editItem in
			NetworkAttachementNewItemView($networks, editItem: editItem)
		} deleteItem: {
			self.networks.removeAll {
				$0.id == selection
			}
		}
	}
}

#Preview {
	NetworkAttachementView(networks: .constant([]))
}
