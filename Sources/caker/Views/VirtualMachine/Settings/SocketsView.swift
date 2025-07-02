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

	var body: some View {
		EditableList($sockets, selection: $selectedItems) { $item in
			SocketsDetailView(currentItem: $item)
		}.onEditItem(selection: $selectedItems) {
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
