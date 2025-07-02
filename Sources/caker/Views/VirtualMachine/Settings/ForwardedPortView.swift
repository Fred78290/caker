//
//  ForwardedPortView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//

import GRPCLib
import SwiftUI

struct ForwardedPortView: View {
	@Binding var forwardPorts: [TunnelAttachement]
	@State private var selectedItems: Set<TunnelAttachement.ID> = []

	var body: some View {
		EditableList($forwardPorts, selection: $selectedItems) { $item in
			ForwardedPortDetailView(currentItem: $item)
		}.onEditItem(selection: $selectedItems) {
			ForwardedPortNewItemView(forwardPorts: $forwardPorts)
		} deleteItem: {
			selectedItems.forEach { selectedItem in
				self.forwardPorts.removeAll {
					$0.id == selectedItem
				}
			}
		}
	}
}

#Preview {
	ForwardedPortView(forwardPorts: .constant([]))
}
