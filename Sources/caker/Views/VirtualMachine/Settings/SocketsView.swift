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

	var body: some View {
		EditableList($sockets) { $item in
			Text(item.description)
		}.onAddItem(systemName: "rectangle.badge.plus") {
			SocketsNewItemView(sockets: $sockets)
		}
	}
}

#Preview {
	SocketsView(sockets: .constant([]))
}
