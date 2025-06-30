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
	@State var selectedItem: SocketDevice? = nil

	var body: some View {
		EditableList($sockets, selection: $selectedItem) { $item in
			SocketsDetailView(currentItem: $item)
		}.onEditItem(selection: $selectedItem) {
			SocketsNewItemView(sockets: $sockets)
		} deleteItem: {
			self.sockets.removeAll {
				$0.id == selectedItem?.id
			}
		}
	}
}

#Preview {
	SocketsView(sockets: .constant([]))
}
