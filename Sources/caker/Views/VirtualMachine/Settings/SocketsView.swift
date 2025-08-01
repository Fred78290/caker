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
	@Binding var disabled: Bool
	@State private var selection: SocketDevice.ID? = nil

	var body: some View {
		GeometryReader { geometry in
			EditableList($sockets, selection: $selection) { $item in
				SocketsDetailView(currentItem: $item)
			}.onEditItem(selection: $selection, disabled: $disabled) { editItem in
				SocketsNewItemView($sockets, editItem: editItem)
			} deleteItem: {
				self.sockets.removeAll {
					$0.id == selection
				}
			}.frame(height: geometry.size.height)
		}
	}
}

#Preview {
	SocketsView(sockets: .constant([]), disabled: .constant(false))
}
