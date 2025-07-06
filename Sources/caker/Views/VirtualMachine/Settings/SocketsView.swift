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
	@State private var selection: SocketDevice.ID? = nil

	var body: some View {
		EditableList($sockets, selection: $selection) { $item in
			SocketsDetailView(currentItem: $item)
		}.onEditItem(selection: $selection) { editItem in
			SocketsNewItemView($sockets, editItem: editItem)
		} deleteItem: {
			self.sockets.removeAll {
				$0.id == selection
			}
		}
	}
}

#Preview {
	SocketsView(sockets: .constant([]))
}
