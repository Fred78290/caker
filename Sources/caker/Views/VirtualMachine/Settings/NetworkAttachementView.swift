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
	@Binding var disabled: Bool
	@State private var selection: BridgeAttachement.ID? = nil

	var body: some View {
		GeometryReader { geometry in
			EditableList($networks, selection: $selection) { $item in
				NetworkAttachementDetailView(currentItem: $item)
			}.onEditItem(selection: $selection, disabled: $disabled) { editItem in
				NetworkAttachementNewItemView($networks, editItem: editItem)
			} deleteItem: {
				self.networks.removeAll {
					$0.id == selection
				}
			}.frame(height: geometry.size.height)
		}
	}
}

#Preview {
	NetworkAttachementView(networks: .constant([]), disabled: .constant(false))
}
