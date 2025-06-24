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
	@State var displaySheet: Bool = false

	var body: some View {
		EditableList($sockets) { $item in
			Text(item.description)
		}.onAddItem(systemName: "rectangle.badge.plus") {
			displaySheet = true
		}.sheet(isPresented: $displaySheet) {
			Text("SocketsView: Add socket")
		}
	}
}

#Preview {
	SocketsView(sockets: .constant([]))
}
