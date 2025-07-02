//
//  SocketsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//

import GRPCLib
import SwiftUI

struct SocketsView: View {
	@Binding var sockets: [SocketDevice]
	@State private var selectedItems: Set<SocketDevice.ID> = []
	@State private var selection: SocketDevice.ID? = nil

	var body: some View {
		EditableList($sockets, selection: $selection, selectedItems: $selectedItems) { $item in
			SocketsDetailView(currentItem: $item)
		}.onEditItem(selection: $selection, selectedItems: $selectedItems) {
			SocketsNewItemView(sockets: $sockets)
		} deleteItem: {
			selectedItems.forEach { selectedItem in
				self.sockets.removeAll {
					$0.id == selectedItem
				}
			}
		}
	}
}

#Preview {
	SocketsView(sockets: .constant([]))
}
